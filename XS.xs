#include <EXTERN.h>
#include <perl.h>
#include <XSUB.h>
#include <stdio.h>

// Util
I32 get_tid_xs();
void noop();
I32 get_tid_xs();
SV *trace(I32 level, I32 wrap, I32 fudge, I32 *depth);
SV* cx_name(const PERL_CONTEXT* cx);

// Hook Related
void run_hooks(SV *ctx, I32 reverse, AV *hooks_ref);
void run_hook (SV *ctx, SV *hook);

// Hub Related
SV *get_todo_xs(SV *hub);
SV *hid_xs(SV *hub);

// Param Parsing
I32 get_level(HV *params);
I32 get_wrap(HV *params);
I32 get_fudge(HV *params);
SV *get_on_init(HV *params);
SV *get_on_release(HV *params);
SV *get_stack(HV *params);
SV *get_hub(HV *params);

// Constructors
SV *new_debuginfo(SV *hub, SV *frame);
SV *new_context(SV *stack, SV *hub, SV *debug, I32 depth);

// Context related
void release_xs(SV *ctx_arg);
void ctx_add_on_release(SV *ctx, HV *params);
I32 ctx_is_canon(SV *hid, SV *ctx);
void ctx_clear_canon(SV *hid);
void ctx_set_canon(SV *hid, SV *ctx);
SV *ctx_get_canon(SV *hid);
void ctx_init(SV *ctx, SV *hub, HV *params);
SV *get_ctx(HV *params);

// Hub Stack related
SV *stack_peek(SV *stack_r);
SV *stack_top(SV *stack);

// {{{ Util
I32 get_tid_xs() {
    CV *tid = get_cv("threads::tid", 0);
    if (!tid) return 0;

    dSP;
    ENTER;
    SAVETMPS;
    PUSHMARK(SP);
    PUTBACK;
    int count = call_pv("threads::tid", G_SCALAR);
    SPAGAIN;
    if (count != 1) croak("XS Error getting tid()");
    I32 out = POPi;
    PUTBACK;
    FREETMPS;
    LEAVE;

    return out;
}

void noop() { return; }

SV* cx_name(const PERL_CONTEXT* cx) {
    if (CxTYPE(cx) == CXt_SUB || CxTYPE(cx) == CXt_FORMAT) {
        GV * const cvgv = CvGV(cx->blk_sub.cv);
        if (isGV(cvgv)) {
            SV * const name = newSV(0);
            gv_efullname3(name, cvgv, NULL);
            return name;
        }
        else {
            return newSVpvn("(unknown)", 9);
        }
    }

    if (CxTYPE(cx) == CXt_EVAL) {
        return newSVpvn("(eval)", 6);
    }

    return NULL;
}

SV *trace(I32 level, I32 wrap, I32 fudge, I32 *depth) {
    I32 at = 0;
    I32 idx;
    I32 found = -1;
    I32 last  = -1;
    SV *lastname = NULL;
    SV *name  = NULL;

    for (idx = cxstack_ix; idx >= 0; idx--) {
        const PERL_CONTEXT* cx = cxstack + idx;

        SV* subname = cx_name(cx);
        if (!subname) continue;

        at++;

        if (at == level) {
            name  = subname;
            found = idx;
        }
        else {
            last = idx;
            if (lastname) SvREFCNT_dec(lastname);
            lastname = subname;
        }
    }

    if (level == 0 && found < 0) {
        found = 0;
        name = newSVpvn("context_xs", 10);
    }

    if (depth) *depth = at - wrap;

    // In fudge mode we use the lowest frame;
    if (found < 0 && fudge) {
        found = last;
        name = lastname;
    }
    else if(lastname) {
        SvREFCNT_dec(lastname);
    }

    if (found < 0) return newSV(0);

    const PERL_CONTEXT* cx = cxstack + found;
    AV *deets = newAV();

    av_push(deets, newSVpv(CopSTASHPV(cx->blk_oldcop), 0));
    av_push(deets, newSVpv(OutCopFILE(cxstack[found].blk_oldcop), 0));
    av_push(deets, newSViv(CopLINE(cxstack[found].blk_oldcop)));
    av_push(deets, name);
    av_push(deets, newSVnv(at - wrap));

    return newRV_noinc((SV*)deets);
}
// }}}

// {{{ Hook Related
void run_hooks(SV *ctx, I32 reverse, AV *hooks) {
    I32 top = av_len(hooks);
    if (top == -1) return;

    I32 i;
    for (i = 0; i <= top; i++) {
        I32 idx = reverse ? top - i : i;
        SV **cbp = av_fetch(hooks, idx, 0);
        if (!cbp) continue;
        SV *cb = *cbp;
        run_hook(ctx, cb);
    }
}

void run_hook(SV *ctx, SV *hook) {
    dSP;

    ENTER;
    SAVETMPS;

    PUSHMARK(SP);
    XPUSHs(sv_2mortal(newSVsv(ctx)));
    PUTBACK;
    call_sv(hook, G_DISCARD);

    FREETMPS;
    LEAVE;
}
// }}}

// {{{ Hub Related
SV *get_todo_xs(SV *hub) {
    SV *out = newSV(0);

    SV** todos_p = hv_fetch((HV *)(SvRV(hub)), "_todo", 5, 0);
    if (!todos_p) return out;
    SV *todos = *todos_p;

    AV *todos_a = (AV*)SvRV(todos);
    I32 top = av_len(todos_a);

    if(top == -1) return out;

    I32 idx;
    for(idx = top; idx >= 0; idx--) {
        SV **item_p = av_fetch(todos_a, idx, 0);
        if (!item_p) return out; // WTF?

        SV *item = *item_p;

        // Found one
        if (SvOK(item)) {
            SvSetSV(out, SvRV(item));
            return out;
        }

        // Found an expired one, strip it from the array
        SV *got = av_pop(todos_a);
        if (got && got == &PL_sv_undef) SvREFCNT_inc(got);
    }

    return out;
}

SV *hid_xs(SV *hub) {
    SV** hid_p = hv_fetch((HV *)(SvRV(hub)), "hid", 3, 0);
    if (!hid_p) return newSV(0);
    SvREFCNT_inc(*hid_p);
    return *hid_p;
}
// }}}

// {{{ Hub Stack related
SV *stack_peek(SV *stack_r) {
    AV *stack = (AV*)SvRV(stack_r);
    I32 top = av_len(stack);
    if (top >= 0) {
        SV **hub = av_fetch(stack, top, 0);
        if (hub && SvOK(*hub)) return *hub;
    }
    return NULL;
}

SV *stack_top(SV *stack) {
    SV *hub = stack_peek(stack);
    if (hub && SvOK(hub)) return hub;

    dSP;

    ENTER;
    SAVETMPS;

    PUSHMARK(SP);
    XPUSHs(sv_2mortal(newSVsv(stack)));
    PUTBACK;
    call_method("new_hub", G_DISCARD);

    FREETMPS;
    LEAVE;

    return stack_peek(stack);
}
// }}}

// Param Parsing {{{
I32 get_level(HV *params) {
    SV** level_p = hv_fetch(params, "level", 5, 0);
    if (level_p && SvOK(*level_p)) return SvIV(*level_p);
    return 0;
}

I32 get_wrap(HV *params) {
    SV** wrap_p = hv_fetch(params, "wrapped", 7, 0);
    if (wrap_p && SvOK(*wrap_p)) return SvIV(*wrap_p);
    return 0;
}

I32 get_fudge(HV *params) {
    SV** fudge_p = hv_fetch(params, "fudge", 5, 0);
    if (fudge_p && SvOK(*fudge_p)) return SvIV(*fudge_p);
    return 0;
}

SV *get_on_init(HV *params) {
    SV **on_init_p = hv_fetch(params, "on_init", 7, 0);
    if (on_init_p && SvOK(*on_init_p)) return *on_init_p;
    return NULL;
}

SV *get_on_release(HV *params) {
    SV **on_release_p = hv_fetch(params, "on_release", 10, 0);
    if (on_release_p && SvOK(*on_release_p)) return *on_release_p;
    return NULL;
}

SV *get_stack(HV *params) {
    SV** stack_p = hv_fetch(params, "stack", 5, 0);
    if (stack_p && SvOK(*stack_p)) return *stack_p;

    SV *stack = get_sv("Test::Stream::Context::STACK", 1);
    if (stack && SvOK(stack)) return stack;

    return NULL;
}

SV *get_hub(HV *params) {
    SV** hub_p = hv_fetch(params, "hub", 3, 0);
    if (hub_p && SvOK(*hub_p)) return *hub_p;

    SV *stack = get_stack(params);
    if (!stack) return NULL;
    return stack_top(stack);
}
// }}}

// {{{ Constructors
SV *new_debuginfo(SV *hub, SV *frame) {
    HV *hub_hv = (HV*)SvRV(hub);

    SV **parent_todo = hv_fetch(hub_hv, "parent_todo", 11, 0);
    SV *ptodo = parent_todo ? newSVsv(*parent_todo) : newSV(0);
    SV *todo  = get_todo_xs(hub);

    HV *dbg_hv = newHV();

    hv_store(dbg_hv, "tid",         3,  newSVnv(get_tid_xs()), 0);
    hv_store(dbg_hv, "pid",         3,  newSVnv(getpid()), 0);
    hv_store(dbg_hv, "parent_todo", 11, ptodo,             0);
    hv_store(dbg_hv, "todo",        4,  todo,              0);
    hv_store(dbg_hv, "frame",       5,  frame,             0);

    HV *dbgstash = gv_stashpv("Test::Stream::DebugInfo", GV_ADD);
    return sv_bless(newRV_noinc((SV*)dbg_hv), dbgstash);
}

SV *new_context(SV *stack, SV *hub, SV *debug, I32 depth) {
    HV *ctx_hv = newHV();
    hv_store(ctx_hv, "stack",  5, newSVsv(stack), 0);
    hv_store(ctx_hv, "hub",    3, newSVsv(hub),   0);
    hv_store(ctx_hv, "debug",  5, newSVsv(debug), 0);
    hv_store(ctx_hv, "_err",   4, newSVsv(ERRSV), 0);
    hv_store(ctx_hv, "_depth", 6, newSVnv(depth), 0);
    hv_store(ctx_hv, "_xs",    3, newSVnv(1),     0);
    HV *ctxstash = gv_stashpv("Test::Stream::Context", GV_ADD);
    return sv_bless(newRV_noinc((SV*)ctx_hv), ctxstash);
}
// }}}

// {{{ Context Related
void release_xs(SV *ctx_arg) {
    // If there are other references we simply undef the callers variable
    if (SvREFCNT(SvRV(ctx_arg)) != 1) {
        SvSetSV(ctx_arg, &PL_sv_undef);
        return;
    }

    // Make a new reference to the context, then undef the callers variable.
    // Make our copy mortal so it cleans up soonish
    SV *ctx = newSVsv(ctx_arg);
    SvSetSV(ctx_arg, &PL_sv_undef);
    sv_2mortal(ctx);

    // Get the hub from the context;
    SV** hub_p = hv_fetch((HV *)(SvRV(ctx)), "hub", 3, 0);
    if (!hub_p) croak("Could not get hub from context.");
    SV* hub = *hub_p;

    // Get the hubs hid
    SV *hid = hid_xs(hub);
    if (!SvOK(hid)) croak("Could not get hid from hub.");
    sv_2mortal(hid); // Clean it up soon

    if (!ctx_is_canon(hid, ctx)) {
        croak("release() should not be called on a non-canonical context.");
    }

    // Delete the context from the canon ctx hash
    ctx_clear_canon(hid);

    // check for context specific callbacks
    SV **cbk_p = hv_fetch((HV *)(SvRV(ctx)), "_on_release", 11, 0);
    SV *cbk = cbk_p ? *cbk_p : &PL_sv_undef;

    // check for hub specific callbacks
    SV **hcbk_p = hv_fetch((HV *)(SvRV(hub)), "_context_release", 16, 0);
    SV *hcbk = hcbk_p ? *hcbk_p : &PL_sv_undef;

    AV *gcbk_a = get_av("Test::Stream::Context::ON_RELEASE", 0);

    // Check if any of the callbacks are populated
    int have_cbk  = SvOK(cbk);
    int have_hcbk = SvOK(hcbk);
    int have_gcbk = gcbk_a ? 1 : 0;

    if (have_cbk)  run_hooks(ctx, 1, (AV*)(SvRV(cbk)));
    if (have_hcbk) run_hooks(ctx, 1, (AV*)(SvRV(hcbk)));
    if (have_gcbk) run_hooks(ctx, 1, gcbk_a);
}

void ctx_add_on_release(SV *ctx, HV *params) {
    SV **on_rel_p = hv_fetch(params, "on_release", 10, 0);
    if (!on_rel_p || !SvOK(*on_rel_p)) return;

    SV *on_release = *on_rel_p;
    HV *ctxh = (HV*)SvRV(ctx);

    SV **release_ref = hv_fetch(ctxh, "_on_release", 11, 0);
    AV *release;
    if (!release_ref || !SvOK(*release_ref)) {
        release = newAV();
        hv_store(ctxh, "_on_release", 11, newRV_noinc((SV*)release), 0);
    }
    else {
        release = (AV *)(SvRV(*release_ref));
    }

    SvREFCNT_inc(*on_rel_p);
    av_push(release, *on_rel_p);
}

void ctx_clear_canon(SV *hid) {
    HV *CTXS = get_hv("Test::Stream::Context::CONTEXTS", 0);
    hv_delete_ent(CTXS, hid, 0, 0);
}

SV *ctx_get_canon(SV *hid) {
    HV *CTXS = get_hv("Test::Stream::Context::CONTEXTS", 0);

    HE *canon_he = hv_fetch_ent(CTXS, hid, 0, 0);
    SV *canon = canon_he ? HeVAL(canon_he) : NULL;
    if (!canon || !SvOK(canon)) return NULL;
    return canon;
}

void ctx_set_canon(SV *hid, SV *ctx) {
    HV *CTXS = get_hv("Test::Stream::Context::CONTEXTS", 0);

    SvREFCNT_inc(hid);
    SV *weak = newSVsv(ctx);
    sv_rvweaken(weak);

    hv_store_ent(CTXS, hid, weak, 0);
}

I32 ctx_is_canon(SV *hid, SV *ctx) {
    // Get the canon contexts hash
    HV *CTXS = get_hv("Test::Stream::Context::CONTEXTS", 0);

    // Check if this context is a canon context
    HE *canon_he = hv_fetch_ent(CTXS, hid, 0, 0);
    SV *canon = canon_he ? HeVAL(canon_he) : NULL;

    if (!canon)                   return 0;
    if (!SvOK(canon))             return 0;
    if (SvRV(canon) == SvRV(ctx)) return 1;

    return 0;
}

void ctx_init(SV *ctx, SV *hub, HV *params) {
    // check for context specific callbacks
    SV **cbkr = hv_fetch(params, "on_init", 7, 0);
    SV *cbk = cbkr ? *cbkr : &PL_sv_undef;

    // check for hub specific callbacks
    SV **hcbkr = hv_fetch((HV *)(SvRV(hub)), "_context_init", 13, 0);
    SV *hcbk = hcbkr ? *hcbkr : &PL_sv_undef;

    AV *gcbk_a = get_av("Test::Stream::Context::ON_INIT", 0);

    // Check if any of the callbacks are populated
    int have_cbk  = SvOK(cbk);
    int have_hcbk = SvOK(hcbk);
    int have_gcbk = gcbk_a ? 1 : 0;

    if (have_gcbk) run_hooks(ctx, 0, gcbk_a);
    if (have_hcbk) run_hooks(ctx, 0, (AV*)(SvRV(hcbk)));
    if (have_cbk)  run_hook(ctx, cbk);
}

SV *get_ctx(HV *params) {
    SV *hub = get_hub(params);
    if (!hub) return newSV(0);

    SV *hid = hid_xs(hub);
    if (!hid || !SvOK(hid)) return newSV(0);
    sv_2mortal(hid); // Clean it up soon

    I32 level = 1 + get_level(params);
    I32 wrap  = get_wrap(params);
    I32 fudge = get_fudge(params);

    I32 depth = -1;
    SV *frame = trace(level, wrap, fudge, &depth);

    if (!frame || !SvOK(frame)) croak("Could not find context at depth %i", level);

    SV *canon = ctx_get_canon(hid);

    SV *ctx = NULL;

    if (canon && SvOK(canon)) {
        HV *chv = (HV *)SvRV(canon);
        SV **depthr = hv_fetch(chv, "_depth", 6, 0);
        I32 cd = depthr ? SvIV(*depthr) : 0;

        if (depth < cd) {
            // Call Depth Error
            dSP;

            ENTER;
            SAVETMPS;

            PUSHMARK(SP);
            XPUSHs(canon);
            XPUSHs(frame);
            PUTBACK;
            call_pv("Test::Stream::Context::_depth_error", G_DISCARD);

            FREETMPS;
            LEAVE;
        }
        else {
            ctx = newSVsv(canon);
        }
    }

    if (!ctx) {
        SV *stack = get_stack(params);
        SV *debug = new_debuginfo(hub, frame);
        ctx = new_context(stack, hub, debug, depth);
        ctx_set_canon(hid, ctx);
        ctx_init(ctx, hub, params);
    }

    ctx_add_on_release(ctx, params);

    return ctx;
}
// }}}

MODULE = Test::Stream::XS  PACKAGE = Test::Stream::XS

void
release_xs(ctx)
        SV *ctx

I32
refcount(thing)
        SV *thing
    CODE:
        if (SvROK(thing)) {
            RETVAL = SvREFCNT(SvRV(thing));
        }
        else {
            croak("Not a reference");
        }
    OUTPUT:
        RETVAL

I32
get_tid_xs()

void
noop(...)

SV*
test_caller(level, wrap, fudge)
        I32 level
        I32 wrap
        I32 fudge
    CODE:
        RETVAL = trace(level, wrap, fudge, NULL);
    OUTPUT:
        RETVAL

SV*
get_todo_xs(hub)
        SV *hub

SV*
hid_xs(hub)
        SV *hub

SV*
peek_xs(stack)
        SV *stack
    CODE:
        SV *got = stack_peek(stack);
        SV *out = newSV(0);
        SvSetSV(out, got);
        RETVAL = out;
    OUTPUT:
        RETVAL

SV*
top_xs(stack)
        SV *stack
    CODE:
        SV *got = stack_top(stack);
        SV *out = newSV(0);
        SvSetSV(out, got);
        RETVAL = out;
    OUTPUT:
        RETVAL

SV*
context_xs(...)
    PREINIT:
        HV *params;
        int i;
    CODE:
        I32 gimme = GIMME_V;
        if (gimme == G_VOID) croak("context() called, but return value is ignored");
        params = newHV();
        for (i = 0; i < items; i += 2) {
            SV *val = newSVsv(ST(i+1));
            if (NULL == hv_store(params, SvPV_nolen(ST(i)), strlen(SvPV_nolen(ST(i))), val, 0)) {
                croak("panic: hv_store() failed to store element in hash");
            }
        }
        RETVAL = get_ctx(params);
    OUTPUT:
        RETVAL

void
_test_run_hooks(ctx, reverse, hooks_ref)
        SV *ctx
        I32 reverse
        SV *hooks_ref
    CODE:
        run_hooks(ctx, reverse, (AV*)(SvRV(hooks_ref)));

void
_test_run_hook(ctx, hook)
        SV *ctx
        SV *hook
    CODE:
        run_hook(ctx, hook);

I32
_test_get_level(...)
    PREINIT:
        HV *params;
        int i;
    CODE:
        params = newHV();
        for (i = 0; i < items; i += 2) {
            SV *val = newSVsv(ST(i+1));
            if (NULL == hv_store(params, SvPV_nolen(ST(i)), strlen(SvPV_nolen(ST(i))), val, 0)) {
                croak("panic: hv_store() failed to store element in hash");
            }
        }

        sv_2mortal((SV*)params);
        RETVAL = get_level(params);
    OUTPUT:
        RETVAL

I32
_test_get_wrap(...)
    PREINIT:
        HV *params;
        int i;
    CODE:
        params = newHV();
        for (i = 0; i < items; i += 2) {
            SV *val = newSVsv(ST(i+1));
            if (NULL == hv_store(params, SvPV_nolen(ST(i)), strlen(SvPV_nolen(ST(i))), val, 0)) {
                croak("panic: hv_store() failed to store element in hash");
            }
        }

        sv_2mortal((SV*)params);
        RETVAL = get_wrap(params);
    OUTPUT:
        RETVAL

I32
_test_get_fudge(...)
    PREINIT:
        HV *params;
        int i;
    CODE:
        params = newHV();
        for (i = 0; i < items; i += 2) {
            SV *val = newSVsv(ST(i+1));
            if (NULL == hv_store(params, SvPV_nolen(ST(i)), strlen(SvPV_nolen(ST(i))), val, 0)) {
                croak("panic: hv_store() failed to store element in hash");
            }
        }

        sv_2mortal((SV*)params);
        RETVAL = get_fudge(params);
    OUTPUT:
        RETVAL

SV*
_test_get_on_init(...)
    PREINIT:
        HV *params;
        SV *out = newSV(0);
        int i;
    CODE:
        params = newHV();
        for (i = 0; i < items; i += 2) {
            SV *val = newSVsv(ST(i+1));
            if (NULL == hv_store(params, SvPV_nolen(ST(i)), strlen(SvPV_nolen(ST(i))), val, 0)) {
                croak("panic: hv_store() failed to store element in hash");
            }
        }

        sv_2mortal((SV*)params);
        SV *got = get_on_init(params);

        if (got) {
            SvSetSV(out, got);
        }
        RETVAL = out;
    OUTPUT:
        RETVAL

SV*
_test_get_on_release(...)
    PREINIT:
        HV *params;
        SV *out = newSV(0);
        int i;
    CODE:
        params = newHV();
        for (i = 0; i < items; i += 2) {
            SV *val = newSVsv(ST(i+1));
            if (NULL == hv_store(params, SvPV_nolen(ST(i)), strlen(SvPV_nolen(ST(i))), val, 0)) {
                croak("panic: hv_store() failed to store element in hash");
            }
        }

        sv_2mortal((SV*)params);
        SV *got = get_on_release(params);

        if (got) {
            SvSetSV(out, got);
        }
        RETVAL = out;
    OUTPUT:
        RETVAL

SV*
_test_get_stack(...)
    PREINIT:
        HV *params;
        SV *got;
        SV *out = newSV(0);
        int i;
    CODE:
        params = newHV();
        for (i = 0; i < items; i += 2) {
            SV *val = newSVsv(ST(i+1));
            if (NULL == hv_store(params, SvPV_nolen(ST(i)), strlen(SvPV_nolen(ST(i))), val, 0)) {
                croak("panic: hv_store() failed to store element in hash");
            }
        }

        sv_2mortal((SV*)params);
        got = get_stack(params);
        if (got) {
            SvSetSV(out, got);
        }
        RETVAL = out;
    OUTPUT:
        RETVAL

SV*
_test_get_hub(...)
    PREINIT:
        HV *params;
        SV *got;
        SV *out = newSV(0);
        int i;
    CODE:
        params = newHV();
        for (i = 0; i < items; i += 2) {
            SV *val = newSVsv(ST(i+1));
            if (NULL == hv_store(params, SvPV_nolen(ST(i)), strlen(SvPV_nolen(ST(i))), val, 0)) {
                croak("panic: hv_store() failed to store element in hash");
            }
        }

        sv_2mortal((SV*)params);
        got = get_hub(params);
        if (got) {
            SvSetSV(out, got);
        }
        RETVAL = out;
    OUTPUT:
        RETVAL

SV*
_test_new_debuginfo(hub, frame)
        SV *hub
        SV *frame
    CODE:
        SvREFCNT_inc(frame);
        RETVAL = new_debuginfo(hub, frame);
    OUTPUT:
        RETVAL

SV*
_test_new_context(stack, hub, debug, depth)
        SV *stack
        SV *hub
        SV *debug
        I32 depth
    CODE:
        RETVAL = new_context(stack, hub, debug, depth);
    OUTPUT:
        RETVAL


void
_test_ctx_add_on_release(ctx, ...)
        SV *ctx
    PREINIT:
        HV *params;
        int i;
    CODE:
        params = newHV();
        for (i = 1; i < items; i += 2) {
            SV *val = newSVsv(ST(i+1));
            if (NULL == hv_store(params, SvPV_nolen(ST(i)), strlen(SvPV_nolen(ST(i))), val, 0)) {
                croak("panic: hv_store() failed to store element in hash");
            }
        }
        sv_2mortal((SV*)params);
        ctx_add_on_release(ctx, params);

void
_test_ctx_clear_canon(hid)
        SV *hid
    CODE:
        ctx_clear_canon(hid);

SV*
_test_ctx_get_canon(hid)
        SV *hid
    CODE:
        SV *canon = ctx_get_canon(hid);
        RETVAL = newSVsv(canon);
    OUTPUT:
        RETVAL

void
_test_ctx_set_canon(hid, ctx)
        SV *hid
        SV *ctx
    CODE:
        ctx_set_canon(hid, ctx);

I32
_test_ctx_is_canon(hid, ctx)
        SV *hid
        SV *ctx
    CODE:
        RETVAL = ctx_is_canon(hid, ctx);
    OUTPUT:
        RETVAL

void
_test_ctx_init(ctx, hub, ...)
        SV *ctx
        SV *hub
    PREINIT:
        HV *params;
        int i;
    CODE:
        params = newHV();
        for (i = 2; i < items; i += 2) {
            SV *val = newSVsv(ST(i+1));
            if (NULL == hv_store(params, SvPV_nolen(ST(i)), strlen(SvPV_nolen(ST(i))), val, 0)) {
                croak("panic: hv_store() failed to store element in hash");
            }
        }
        sv_2mortal((SV*)params);
        ctx_init(ctx, hub, params);


