#!/usr/bin/env python
#
# arm-as-to-ios     Modify ARM assembly code for the iOS assembler
#
# Copyright (c) 2012 Psellos   http://psellos.com/
# Licensed under the MIT License:
#     http://www.opensource.org/licenses/mit-license.php
#
# Resources for running OCaml on iOS: http://psellos.com/ocaml/
#
import sys
import re

VERSION = '1.4.0'

# Character classes for expression lexing.
#
g_ccid0 = '[$.A-Z_a-z\x80-\xff]'      # Beginning of id
g_ccid =  '[$.0-9A-Z_a-z\x80-\xff]'   # Later in id
def ccc(cc):                          # Complement the class
    if cc[1] == '^':
        return cc[0] + cc[2:]
    return cc[0] + '^' + cc[1:]
def ccce(cc):                         # Complement the class, include EOL
    return '(?:' + ccc(cc) + '|$)'

# Prefixes for pooled symbol labels and jump table base labels.  They're
# in the space of Linux assembler local symbols.  Later rules will
# modify them to the Loc() form.
#
g_poolpfx = '.LP'
g_basepfx = '.LB'


def exists(p, l):
    for l1 in l:
        if p(l1):
            return True
    return False


def forall(p, l):
    for l1 in l:
        if not p(l1):
            return False
    return True


def add_prefix(instrs):
    # Add compatibility macros for all systems, plus hardware
    # definitions and compatibility macros for iOS.
    #
    # All systems:
    #
    # Glo()     cpp macro for making global symbols (xxx vs _xxx)
    # Loc()     cpp macro for making local symbols (.Lxxx vs Lxxx)
    # .funtype  Expands to .thumb_func for iOS armv7 (null for armv6)
    #           Expands to .type %function for others
    #
    # iOS:
    #
    # .machine  armv6/armv7
    # .thumb    (for armv7)
    # cbz       Expands to cmp/beq for armv6 (Thumb-only instr)
    # .type     Not supported by Apple assembler
    # .size     Not supported by Apple assembler
    #
    defre = '#[ \t]*if.*def.*SYS'  # Add new defs near first existing ones
    skipre = '$|\.syntax[ \t]'     # Skip comment lines (and .syntax)

    for i in range(len(instrs)):
        if re.match(defre, instrs[i][1]):
            break
    else:
        i = 0
    for i in range(i, len(instrs)):
        if not re.match(skipre, instrs[i][1]):
            break
    instrs[i:0] = [
        ('', '', '\n'),
        ('/* Apple compatibility macros */', '', '\n'),
        ('', '#if defined(SYS_macosx)', '\n'),
        ('', '#define Glo(s) _##s', '\n'),
        ('', '#define Loc(s) L##s', '\n'),
        ('', '#if defined(MODEL_armv6)', '\n'),
        ('        ', '.machine  armv6', '\n'),
        ('        ', '.macro  .funtype', '\n'),
        ('        ', '.endm', '\n'),
        ('        ', '.macro  cbz', '\n'),
        ('        ', 'cmp     $0, #0', '\n'),
        ('        ', 'beq     $1', '\n'),
        ('        ', '.endm', '\n'),
        ('', '#else', '\n'),
        ('        ', '.machine  armv7', '\n'),
        ('        ', '.thumb', '\n'),
        ('        ', '.macro  .funtype', '\n'),
        ('        ', '.thumb_func $0', '\n'),
        ('        ', '.endm', '\n'),
        ('', '#endif', '\n'),
        ('        ', '.macro  .type', '\n'),
        ('        ', '.endm', '\n'),
        ('        ', '.macro  .size', '\n'),
        ('        ', '.endm', '\n'),
        ('', '#else', '\n'),
        ('', '#define Glo(s) s', '\n'),
        ('', '#define Loc(s) .L##s', '\n'),
        ('        ', '.macro  .funtype symbol', '\n'),
        ('        ', '.type  \\symbol, %function', '\n'),
        ('        ', '.endm', '\n'),
        ('', '#endif', '\n'),
        ('/* End Apple compatibility macros */', '', '\n'),
        ('', '', '\n')
    ]
    return instrs


# Regular expression for modified ldr lines
#
g_ldre = '(ldr[ \t][^,]*,[ \t]*)=(([^ \t\n@,/]|/(?!\*))*)(.*)'


def explicit_address_loads(instrs):
    # Linux assemblers allow the following:
    #
    #     ldr rM, =symbol
    #
    # which loads rM with [mov] (immediately) if possible, or creates an
    # entry in memory for the symbol value and loads it PC-relatively
    # with [ldr].
    #
    # The Apple assembler doesn't seem to support this notation.  If the
    # value is a suitable constant, it emits a valid [mov].  Otherwise
    # it seems to emit an invalid [ldr] that always generates an error.
    # (At least I have not been able to make it work).  So, change uses
    # of =symbol to explicit PC-relative loads.
    #
    # This requires a pool containing the addresses to be loaded.  For
    # now, we just keep track of it ourselves and emit it into the text
    # segment at the end of the file.
    #
    syms = {}
    result = []

    def repl1((syms, result), (a, b, c)):
        global g_poolpfx
        global g_ldre
        (b1, b2, b3) = parse_iparts(b)
        mo = re.match(g_ldre, b3, re.DOTALL)
        if mo:
            if mo.group(2) not in syms:
                syms[mo.group(2)] = len(syms)
            psym = mo.group(2)
            if psym[0:2] == '.L':
                psym = psym[2:]
            newb3 = mo.group(1) + g_poolpfx + psym + mo.group(4)
            result.append((a, b1 + b2 + newb3, c))
        else:
            result.append((a, b, c))
        return (syms, result)

    def pool1(result, s):
        global g_poolpfx
        psym = s
        if psym[0:2] == '.L':
            psym = psym[2:]
        result.append(('', g_poolpfx + psym + ':', '\n'))
        result.append(('        ', '.long ' + s, '\n'))
        return result

    reduce(repl1, instrs, (syms, result))
    if len(syms) > 0:
        result.append(('', '', '\n'))
        result.append(('/* Pool of addresses loaded into registers */',
                        '', '\n'))
        result.append(('', '', '\n'))
        result.append(('        ', '.text', '\n'))
        result.append(('        ', '.align 2', '\n'))
        reduce(pool1, sorted(syms, key=syms.get), result)
    return result


def global_symbols(instrs):
    # The form of a global symbol differs between Linux assemblers and
    # the Apple assember:
    #
    # Linux: xxx
    # Apple: _xxx
    #
    # Change occurrences of global symbols to use the Glo() cpp macro
    # defined in our prefix.
    #
    # We consider a symbol to be global if:
    #
    # a.  It appears in a .globl declaration; or
    # b.  It is referenced, has global form, and is not defined
    #
    glosyms = set()
    refsyms = set()
    defsyms = set()
    result = []

    def findglo1 (glosyms, (a, b, c)):
        if re.match('#', b):
            # Preprocessor line; nothing to do
            return glosyms
        (b1, b2, b3) = parse_iparts(b)
        mo = re.match('(\.globl)' + ccce(g_ccid), b3)
        if mo:
            tokens = parse_expr(b3[len(mo.group(1)):])
            if forall(lambda t: token_type(t) in ['space', 'id', ','], tokens):
                for t in tokens:
                    if token_type(t) == 'id':
                        glosyms.add(t)
        return glosyms

    def findref1 ((refsyms, skipct), (a, b, c)):

        def looksglobal(s):
            if re.match('(r|a|v|p|c|cr|f|s|d|q|mvax|wcgr)[0-9]+$', s, re.I):
                return False # numbered registers
            if re.match('(wr|sb|sl|fp|ip|sp|lr|pc)$', s, re.I):
                return False # named registers
            if re.match('(fpsid|fpscr|fpexc|mvfr1|mvfr0)$', s, re.I):
                return False # more named registers
            if re.match('(mvf|mvd|mvfx|mvdx|dspsc)$', s, re.I):
                return False # even more named registers
            if re.match('(wcid|wcon|wcssf|wcasf|acc)$', s, re.I):
                return False # even more named registers
            if re.match('\.$|\.L|[0-9]|#', s):
                return False # dot, local symbol, or number
            if re.match('(asl|lsl|lsr|asr|ror|rrx)$', s, re.I):
                return False # shift names
            return True

        if re.match('#', b):
            # Preprocessor line; nothing to do
            return (refsyms, skipct)

        # Track nesting of .macro/.endm.  For now, we don't look for
        # global syms in macro defs.  (Avoiding scoping probs etc.)
        #
        if skipct > 0 and re.match('\.(endm|endmacro)' + ccce(g_ccid), b):
            return (refsyms, skipct - 1)
        if re.match('\.macro' + ccce(g_ccid), b):
            return (refsyms, skipct + 1)
        if skipct > 0:
            return (refsyms, skipct)
        if re.match('\.(type|size|syntax|arch|fpu)' + ccce(g_ccid), b):
            return (refsyms, skipct)

        (b1, b2, b3) = parse_iparts(b)
        rtokens = parse_rexpr(b3)
        if len(rtokens) > 1 and rtokens[1] == '.req':
            # .req has atypical syntax; no symbol refs there anyway
            return (refsyms, skipct)
        for t in rtokens[1:]:
            if token_type(t) == 'id' and looksglobal(t):
                refsyms.add(t)
        return (refsyms, skipct)

    def finddef1(defsyms, (a, b, c)):
        if re.match('#', b):
            # Preprocessor line
            return defsyms
        (b1, b2, b3) = parse_iparts(b)
        rtokens = parse_rexpr(b3)
        if b1 != '':
            defsyms.add(b1)
        if len(rtokens) > 1 and rtokens[1] == '.req':
            defsyms.add(rtokens[0])
        return defsyms

    def repl1((glosyms, result), (a, b, c)):
        if re.match('#', b):
            # Preprocessor line
            result.append((a, b, c))
            return (glosyms, result)
        toglo = lambda s: 'Glo(' + s + ')'
        (b1, b2, b3) = parse_iparts(b)
        tokens = parse_expr(b3)

        if b1 in glosyms:
            b1 = toglo(b1)
        for i in range(len(tokens)):
            if token_type(tokens[i]) == 'id' and tokens[i] in glosyms:
                tokens[i] = toglo(tokens[i])
        result.append((a, b1 + b2 + ''.join(tokens), c))
        return (glosyms, result)

    reduce(findglo1, instrs, glosyms)
    reduce(findref1, instrs, (refsyms, 0))
    reduce(finddef1, instrs, defsyms)
    glosyms |= (refsyms - defsyms)
    reduce(repl1, instrs, (glosyms, result))
    return result


def local_symbols(instrs):
    # The form of a local symbol differs between Linux assemblers and
    # the Apple assember:
    #
    # Linux: .Lxxx
    # Apple: Lxxx
    #
    # Change occurrences of local symbols to use the Loc() cpp macro
    # defined in our prefix.
    #
    lsyms = set()
    result = []

    def find1 (lsyms, (a, b, c)):
        mo = re.match('(\.L[^ \t:]*)[ \t]*:', b)
        if mo:
            lsyms.add(mo.group(1))
        return lsyms

    def repl1((lsyms, result), (a, b, c)):
        matches = list(re.finditer('\.L[^ \t@:,+*/\-()]+', b))
        if matches != []:
            matches.reverse()
            newb = b
            for mo in matches:
                if mo.group() in lsyms:
                    newb = newb[0:mo.start()] + \
                            'Loc(' + mo.group()[2:] + ')' + \
                            newb[mo.end():]
            result.append((a, newb, c))
        else:
            result.append((a, b, c))
        return (lsyms, result)

    reduce(find1, instrs, lsyms)
    reduce(repl1, instrs, (lsyms, result))
    return result


def funtypes(instrs):
    # Linux assemblers accept declarations like this:
    #
    #     .type  symbol, %function
    #
    # For Thumb functions, the Apple assembler wants to see:
    #
    #     .thumb_func symbol
    #
    # Handle this by converting declarations to this:
    #
    #     .funtype symbol
    #
    # Our prefix defines an appropriate .funtype macro for each
    # environment.
    #
    result = []

    def repl1(result, (a, b, c)):
        mo = re.match('.type[ \t]+([^ \t,]*),[ \t]*%function', b)
        if mo:
            result.append((a, '.funtype  ' + mo.group(1), c))
        else:
            result.append((a, b, c))
        return result

    reduce(repl1, instrs, result)
    return result


def jump_tables(instrs):
    # Jump tables for Linux assemblers often look like this:
    #
    #     tbh [pc, rM, lsl #1]
    #     .short (.Labc-.)/2+0
    #     .short (.Ldef-.)/2+1
    #     .short (.Lghi-.)/2+2
    #
    # The Apple assembler disagrees about the meaning of this code,
    # producing jump tables that don't work.  Convert to the following:
    #
    #     tbh [pc, rM, lsl #1]
    # .LBxxx:
    #     .short (.Labc-.LBxxx)/2
    #     .short (.Ldef-.LBxxx)/2
    #     .short (.Lghi-.LBxxx)/2
    #
    # In fact we just convert sequences of .short pseudo-ops of the
    # right form.  There's no requirement that they follow a tbh
    # instruction.
    #
    baselabs = []
    result = []

    def short_match(seq, op):
        # Determine whether the op is a .short of the form that needs to
        # be converted: .short (symbol-.)/2+k.  If so, return a pair
        # containing the symbol and the value of k.  If not, return
        # None.  The short can only be converted if there were at least
        # k other .shorts in sequence before the current one.  A summary
        # of the previous .shorts is in seq.
        #
        # (A real parser would do a better job, but this was quick to
        # get working.)
        #
        sp = '([ \t]|/\*.*?\*/)*'              # space
        sp1 = '([ \t]|/\*.*?\*/)+'             # at least 1 space
        spe = '([ \t]|/\*.*?\*/|@[^\n]*)*$'    # end-of-instr space
        expr_re0 = (
            '\.short' + sp + '\(' + sp +       # .short (
            '([^ \t+\-*/@()]+)' + sp +         # symbol
            '-' + sp + '\.' + sp + '\)' + sp + # -.)
            '/' + sp + '2' + spe               # /2 END
        )
        expr_re1 = (
            '\.short' + sp + '\(' + sp +       # .short (
            '([^ \t+\-*/@()]+)' + sp +         # symbol
            '-' + sp + '\.' + sp + '\)' + sp + # -.)
            '/' + sp + '2' + sp +              # /2
            '\+' + sp +                        # +
            '((0[xX])?[0-9]+)' + spe           # k END
        )
        expr_re2 = (
            '\.short' + sp1 +                  # .short
            '((0[xX])?[0-9]+)' + sp +          # k
            '\+' + sp + '\(' + sp +            # +(
            '([^ \t+\-*/@()]+)' + sp +         # symbol
            '-' + sp + '\.' + sp + '\)' + sp + # -.)
            '/' + sp + '2' + spe               # /2 END
        )
        mo = re.match(expr_re0, op)
        if mo:
            return(mo.group(3), 0)
        mo = re.match(expr_re1, op)
        if mo:
            k = int(mo.group(11), 0)
            if k > len(seq):
                return None
            return (mo.group(3), k)
        mo = re.match(expr_re2, op)
        if mo:
            k = int(mo.group(2), 0)
            if k > len(seq):
                return None
            return (mo.group(7), k)
        return None

    def conv1 ((baselabs, shortseq, label, result), (a, b, c)):
        # Convert current instr (a,b,c) if it's a .short of the right
        # form that spans a previous sequence of .shorts.
        #
        (b1, b2, b3) = parse_iparts(b)

        if b3 == '':
            # No operation: just note label if present.
            result.append((a, b, c))
            if re.match('\.L.', b1):
                return (baselabs, shortseq, b1, result)
            return (baselabs, shortseq, label, result)

        if not re.match('.short[ \t]+[^ \t@]', b3):
            # Not a .short: clear shortseq and label
            result.append((a, b, c))
            return (baselabs, [], '', result)

        # We have a .short: figure out the label if any
        if re.match('\.L', b1):
            sl = b1
        else:
            sl = label

        mpair = short_match(shortseq, b3)
        if not mpair:
            # A .short, but not of right form
            shortseq.append((len(result), sl))
            result.append((a, b, c))
            return (baselabs, shortseq, '', result)

        # OK, we have a .short to convert!
        (sym, k) = mpair
        shortseq.append((len(result), sl))

        # Figure out base label (create one if necessary).
        bx = len(shortseq) - 1 - k
        bl = shortseq[bx][1]
        if bl == '':
            bl = g_basepfx + str(shortseq[bx][0])
            shortseq[bx] = (shortseq[bx][0], bl)
            baselabs.append(shortseq[bx])

        op = '.short\t(' + sym + '-' + bl + ')/2'

        result.append ((a, b1 + b2 + op, c))
        return (baselabs, shortseq, '', result)

    # Convert, accumulate result and new labels.
    reduce(conv1, instrs, (baselabs, [], '', result))

    # Add labels created here to the instruction stream.
    baselabs.reverse()
    for (ix, lab) in baselabs:
        result[ix:0] = [('', lab + ':', '\n')]

    # That does it
    return result


def dot_relative(instrs):
    # The Apple assembler (or possibly the linker) has trouble with code
    # that looks like this:
    #
    #     .word   .Label - . + 0x80000000
    #     .word   0x1966
    # .Label:
    #     .word   0x1967
    #
    # One way to describe the problem is that the assembler marks the
    # first .word for relocation when in fact it's an assembly-time
    # constant.  Translate to the following form, which doesn't generate
    # a relocation marking:
    #
    # DR0 =       .Label - . + 0x80000000
    #     .word   DR0
    #     .word   0x1966
    # .Label:
    #     .word   0x1967
    #
    prefix = 'DR'
    pseudos = '(\.byte|\.short|\.word|\.long|\.quad)'
    result = []

    def tok_ok(t):
        return t in ['.', '+', '-', '(', ')'] or \
            token_type(t) in ['space', 'locid', 'number']

    def dotrel_match(expr):
        # Determine whether the expression is one that needs to be
        # translated.
        tokens = parse_expr(expr)
        return forall(tok_ok, tokens) and \
            exists(lambda t: token_type(t) == 'locid', tokens) and \
            exists(lambda t: token_type(t) == 'number', tokens) and \
            exists(lambda t: t == '-', tokens) and \
            exists(lambda t: t == '.', tokens)

    def conv1(result, (a, b, c)):
        if re.match('#', b):
            # Preprocessor line
            result.append((a, b, c))
        else:
            (b1, b2, b3) = parse_iparts(b)
            mo = re.match(pseudos + ccce(g_ccid), b3)
            if mo:
                p = mo.group(1)
                expr = b3[len(p):]
                if dotrel_match(expr):
                    sym = prefix + str(len(result))
                    instr = sym + ' =' + expr
                    result.append(('', instr, '\n'))
                    result.append((a, b1 + b2 + p + ' ' + sym, c))
                else:
                    result.append((a, b, c))
            else:
                result.append((a, b, c))
        return result

    reduce(conv1, instrs, result)
    return result


def read_input():
    # Concatenate all the input files into a string.
    #
    def fnl(s):
        if s == '' or s[-1] == '\n':
            return s
        else:
            return s + '\n'

    if len(sys.argv) < 2:
        return fnl(sys.stdin.read())
    else:
        input = ""
        for f in sys.argv[1:]:
            try:
                fd = open(f)
                input = input + fnl(fd.read())
                fd.close()
            except:
                sys.stderr.write('arm-as-to-ios: cannot open ' + f + '\n')
        return input


def parse_instrs(s):
    # Parse the string into assembly instructions, also noting C
    # preprocessor lines.  Each instruction is represented as a triple:
    # (space/comments, instruction, end).  The end is either ';' or
    # '\n'.
    #
    def goodmo(mo):
        if mo == None:
            # Should never happen
            sys.stderr.write('arm-as-to-ios: internal parsing error\n')
            sys.exit(1)

    cpp_re = '([ \t]*)(#([^\n]*\\\\\n)*[^\n]*[^\\\\\n])\n'
    comment_re = '[ \t]*#[^\n]*'
    instr_re = (
        '(([ \t]|/\*.*?\*/|@[^\n]*)*)'  # Spaces & comments
        '(([ \t]|/\*.*?\*/|[^;\n])*)'   # "Instruction"
        '([;\n])'                       # End
    )
    instrs = []
    while s != '':
        if re.match('[ \t]*#[ \t]*(if|ifdef|elif|else|endif|define)', s):
            mo = re.match(cpp_re, s)
            goodmo(mo)
            instrs.append((mo.group(1), mo.group(2), '\n'))
        elif re.match('[ \t]*#', s):
            mo = re.match(comment_re, s)
            goodmo(mo)
            instrs.append((mo.group(0), '', '\n'))
        else:
            mo = re.match(instr_re, s, re.DOTALL)
            goodmo(mo)
            instrs.append((mo.group(1), mo.group(3), mo.group(5)))
        s = s[len(mo.group(0)):]
    return instrs


def parse_iparts(i):
    # Parse an instruction into smaller parts, returning a triple of
    # strings (label, colon, operation).  The colon part also contains
    # any surrounding spaces and comments (making the label and the
    # operation cleaner to process).
    #
    # (Caller warrants that the given string doesn't start with space or
    # a comment.  This is true for strings returned by the instruction
    # parser.)
    #
    lab_re = (
        '([^ \t:/@]+)'                  # Label
        '(([ \t]|/\*.*?\*/|@[^\n]*)*)'  # Spaces & comments
        ':'                             # Colon
        '(([ \t]|/\*.*?\*/|@[^\n]*)*)'  # Spaces & comments
        '([^\n]*)'                      # Operation
    )

    if len(i) > 0 and i[0] == '#':
        # C preprocessor line; treat as operation.
        return ('', '', i)
    mo = re.match(lab_re, i)
    if mo:
        return (mo.group(1), mo.group(2) + ':' + mo.group(4), mo.group(6))
    # No label, just an operation
    return ('', '', i)


def parse_expr(s):
    # Parse a string into a sequence of tokens.  A segment of white
    # space (including comments) is treated as a token, so that the
    # tokens can be reassembled into the string again.
    #
    result = []
    while s != '':
        mo = re.match('([ \t]|/\*.*?\*/|@.*)+', s)
        if not mo:
            # Glo(...) and Loc(...) are single tokens
            mo = re.match('(Glo|Loc)\([^()]*\)', s)
        if not mo:
            mo = re.match('"([^\\\\"]|\\\\.)*"', s)
        if not mo:
            mo = re.match(g_ccid0 + g_ccid + '*', s)
        if not mo:
            mo = re.match('[0-9]+[bf]', s)
        if not mo:
            mo = re.match('0[Xx][0-9a-fA-F]+|[0-9]+', s)
        if not mo:
            mo = re.match('.', s)
        result.append(mo.group(0))
        s = s[len(mo.group(0)):]
    return result


def parse_rexpr(s):
    # Like parse_expr(), but return only "real" tokens, not the
    # intervening space.
    #
    return filter(lambda t: token_type(t) != 'space', parse_expr(s))


def token_type(t):
    # Determine the type of a token.  Caller warrants that it was
    # returned by parse_expr() or parse_rexpr().
    #
    if re.match('[ \t]|/\*|@', t):
        return 'space'
    if re.match('Glo\(', t):
        return 'gloid'
    if re.match('Loc\(', t):
        return 'locid'
    if re.match('"', t):
        return 'string'
    if re.match(g_ccid0, t):
        return 'id'
    if re.match('[0-9]+[bf]', t):
        return 'label'
    if re.match('[0-9]', t):
        return 'number'
    return t # Sui generis


def debug_parse(a, b, c):
    # Show results of instuction stream parse.
    #
    (b1, b2, b3) = parse_iparts(b)
    newb = '{' + b1 + '}' + '{' + b2 + '}' + '{' + b3 + '}'
    sys.stdout.write('{' + a + '}' + newb + c)


def main():
    instrs = parse_instrs(read_input())
    instrs = explicit_address_loads(instrs)
    instrs = funtypes(instrs)
    instrs = jump_tables(instrs)
    instrs = global_symbols(instrs)
    instrs = local_symbols(instrs)
    instrs = dot_relative(instrs)
    instrs = add_prefix(instrs)
    for (a, b, c) in instrs:
       sys.stdout.write(a + b + c)


main()