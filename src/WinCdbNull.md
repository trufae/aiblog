# Fixing a Radare2 bug from the Windows Cmd

- **Published:** November 23, 2025
- **Author:** pancake

---

## Introduction

blabla: windows is pain, from the unix perspective it feels a little weird

## Building from git

preconfigure.bat

## Spotting the bug

blabla: running aaaa and then ^C leaves the shell

## Error Codes

blabla: negative numbers are confusing

## Coredumps

blabla: the crashlog and minidump

```
C:\Users\pancake\AppData\Local\CrashDumps>copy radare2.exe.12964.dmp C:\users\pancake\prg\radare2\prefix\bin
```

```
C:\Users\pancake\prg\radare2\prefix\bin>wevtutil qe Application /q:"*[System[(Level=2) and (Provider[@Name='Application Error'])]]" /f:text /c:5

lting package-relative application ID:

Event[2]
  Log Name: Application
  Source: Application Error
  Date: 2025-11-11T11:44:42.9510000Z
  Event ID: 1000
  Task: Application Crashing Events
  Level: Error
  Opcode: Info
  Keyword: N/A
  User: S-1-5-21-3124587653-3600490378-1062075455-1001
  User Name: WOP\pancake
  Computer: wop
  Description:
Faulting application name: radare2.exe, version: 0.0.0.0, time stamp: 0x69130e8f
Faulting module name: ucrtbased.dll, version: 10.0.26100.1, time stamp: 0xd920ed64
Exception code: 0xc0000409
Fault offset: 0x000000000009924c
Faulting process id: 0x48E0
Faulting application start time: 0x1DC52F823F57E9D
Faulting application path: C:\Users\pancake\prg\radare2\prefix\bin\radare2.exe
Faulting module path: C:\WINDOWS\SYSTEM32\ucrtbased.dll
Report Id: 9aac977b-32c7-4c72-992c-b34109ebed80
Faulting package full name:
Faulting package-relative application ID:
```

## Debuggging

We will need the cdb program

https://developer.microsoft.com/en-us/windows/downloads/windows-sdk/

this is installed outside the PATH, as usual, because windows dont want you to use what you have just installed unless you type a boring batch oneliner to get the path in place.

Luckily the preconfigure.bat is not only setting the path for python, visual studio, but also for the windows debugger sdk.

* tasklist -> like `ps`
* debugging cdb radare2 rax2.exe -> ^C captured by cdb, not r2, cant repro
* attach with cdb -p pid

Exception events, so even if we tell cdb to ignore the ^C event, it just hook its and prints a message but the null exception doesnt triggers.. we will need to check the crashdump

```
0:001> sxn c000013a
0:001> g
(d04.920): Control-C exception - code 40010005 (first chance)
First chance exceptions are reported before any exception handling.
This exception may be expected and handled.
KERNELBASE!CtrlRoutine+0x1c4:
00007fff`bfe8c254 0f1f440000      nop     dword ptr [rax+rax]
0:001> sxn 40010005
0:001> g
(d04.1f94): Control-C exception - code 40010005 (first chance)
(d04.27a0): Control-C exception - code 40010005 (first chance)
(d04.4544): Control-C exception - code 40010005 (first chance)
(d04.49c8): Control-C exception - code 40010005 (first chance)
(d04.4c28): Control-C exception - code 40010005 (first chance)
(d04.ef0): Control-C exception - code 40010005 (first chance)
(d04.35b8): Control-C exception - code 40010005 (first chance)
(d04.1674): Control-C exception - code 40010005 (first chance)
ModLoad: 00007fff`be540000 00007fff`be55b000   C:\WINDOWS\SYSTEM32\kernel.appcore.dll
ntdll!NtTerminateProcess+0x14:
00007fff`c2782174 c3              ret
```


## Minidump

```
C:\Users\pancake\prg\radare2\prefix\bin>cdb -z radare2.exe.15500.dmp

************* Preparing the environment for Debugger Extensions Gallery repositories **************
   ExtensionRepository : Implicit
   UseExperimentalFeatureForNugetShare : true
   AllowNugetExeUpdate : true
   NonInteractiveNuget : true
   AllowNugetMSCredentialProviderInstall : true
   AllowParallelInitializationOfLocalRepositories : true

   EnableRedirectToV8JsProvider : false

   -- Configuring repositories
      ----> Repository : LocalInstalled, Enabled: true
      ----> Repository : UserExtensions, Enabled: true

>>>>>>>>>>>>> Preparing the environment for Debugger Extensions Gallery repositories completed, duration 0.015 seconds

************* Waiting for Debugger Extensions Gallery to Initialize **************

>>>>>>>>>>>>> Waiting for Debugger Extensions Gallery to Initialize completed, duration 0.016 seconds
   ----> Repository : UserExtensions, Enabled: true, Packages count: 0
   ----> Repository : LocalInstalled, Enabled: true, Packages count: 30

Microsoft (R) Windows Debugger Version 10.0.26100.7175 AMD64
Copyright (c) Microsoft Corporation. All rights reserved.


Loading Dump File [C:\Users\pancake\prg\radare2\prefix\bin\radare2.exe.15500.dmp]
User Mini Dump File: Only registers, stack and portions of memory are available

Symbol search path is: srv*
Executable search path is:
Windows 10 Version 26200 MP (16 procs) Free x64
Product: WinNt, suite: SingleUserTS
Edition build lab: 26100.1.amd64fre.ge_release.240331-1435
Debug session time: Sat Nov 22 12:17:15.000 2025 (UTC + 1:00)
System Uptime: 10 days 22:20:51.327
Process Uptime: 0 days 0:03:35.000
........................................................
WARNING: Teb 1 pointer is NULL - defaulting to 00000000`7ffde000
WARNING: 00000000`7ffde000 does not appear to be a TEB
This dump file has an exception of interest stored in it.
The stored exception information can be accessed via .ecxr.
(3c8c.4054): Access violation - code c0000005 (first/second chance not available)
WARNING: Teb 1 pointer is NULL - defaulting to 00000000`7ffde000
WARNING: 00000000`7ffde000 does not appear to be a TEB
For analysis of this file, run !analyze -v
WARNING: Teb 1 pointer is NULL - defaulting to 00000000`7ffde000
WARNING: 00000000`7ffde000 does not appear to be a TEB
00000000`00000000 ??              ???
0:001> kb
WARNING: Teb 1 pointer is NULL - defaulting to 00000000`7ffde000
WARNING: 00000000`7ffde000 does not appear to be a TEB
RetAddr               : Args to Child                                                           : Call Site
00000000`00000000     : 00000000`00000000 00000000`00000000 00000000`00000000 00000000`00000000 : 0x0
0:001> r
rax=0000000000000000 rbx=0000000000000000 rcx=0000000000000000
rdx=0000000000000000 rsi=0000000000000000 rdi=0000000000000000
rip=0000000000000000 rsp=0000000000000000 rbp=0000000000000000
 r8=0000000000000000  r9=0000000000000000 r10=0000000000000000
r11=0000000000000000 r12=0000000000000000 r13=0000000000000000
r14=0000000000000000 r15=0000000000000000
iopl=0         nv up di pl nz na pe nc
cs=0000  ss=0000  ds=0000  es=0000  fs=0000  gs=0000             efl=00000000
00000000`00000000 ??              ???
0:001> 
```

blabla: oh wait all register values are zero?

## The CDB Shell

the cdb shell reminds me to the good old times of debug.com, using similar 1-2 letter commands like in r2land

u ; unassemble
r ; regs
d ; dump
g ; go (aka run / continue)
kb          ; backtrace bàsic
kp          ; backtrace amb paràmetres
kv          ; backtrace verbós

```
0:001> ?

Open debugger.chm for complete debugger documentation

B[C|D|E][<bps>] - clear/disable/enable breakpoint(s)
BL - list breakpoints
BA <access> <size> <addr> - set processor breakpoint
BP <address> - set soft breakpoint
D[type][<range>] - dump memory
DT [-n|y] [[mod!]name] [[-n|y]fields]
   [address] [-l list] [-a[]|c|i|o|r[#]|v] - dump using type information
DV [<name>] - dump local variables
DX [-r[#]] <expr> - display C++ expression using extension model (e.g.: NatVis)
E[type] <address> [<values>] - enter memory values
G[H|N] [=<address> [<address>...]] - go
K <count> - stacktrace
KP <count> - stacktrace with source arguments
LM[k|l|u|v] - list modules
LN <expr> - list nearest symbols
P [=<addr>] [<value>] - step over
Q - quit
R [[<reg> [= <expr>]]] - view or set registers
S[<opts>] <range> <values> - search memory
SX [{e|d|i|n} [-c "Cmd1"] [-c2 "Cmd2"] [-h] {Exception|Event|*}] - event filter
T [=<address>] [<expr>] - trace into
U [<range>] - unassemble
version - show debuggee and debugger version
X [<*|module>!]<*|symbol> - view symbols
? <expr> - display expression
?? <expr> - display C++ expression
$< <filename> - take input from a command file

<expr> unary ops: + - not by wo dwo qwo poi hi low
       binary ops: + - * / mod(%) and(&) xor(^) or(|)
       comparisons: == (=) < > !=
       operands: number in current radix, public symbol, <reg>
<type> : b (byte), w (word), d[s] (doubleword [with symbols]),
         a (ascii), c (dword and Char), u (unicode), l (list)
         f (float), D (double), s|S (ascii/unicode string)
         q (quadword)
<pattern> : [(nt | <dll-name>)!]<var-name> (<var-name> can include ? and *)
<range> : <address> <address>
        : <address> L <count>

User-mode options:
~ - list threads status
~#s - set default thread
| - list processes status
|#s - set default process

x64 options:
DG <selector> - dump selector
<reg> : [r|e]ax, [r|e]bx, [r|e]cx, [r|e]dx, [r|e]si, [r|e]di, [r|e]bp, [r|e]sp, [r|e]ip, [e]fl,
        r8-r15 with b/w/d subregisters
        al, ah, bl, bh, cl, ch, dl, dh, cs, ds, es, fs, gs, ss
        sil, dil, bpl, spl
        dr0, dr1, dr2, dr3, dr6, dr7
        fpcw, fpsw, fptw, st0-st7, mm0-mm7
         xmm0-xmm15
<flag> : iopl, of, df, if, tf, sf, zf, af, pf, cf
<addr> : #<16-bit protect-mode [seg:]address>,
         &<V86-mode [seg:]address>

Open debugger.chm for complete debugger documentation

0:001>
```

## Cdb Plugins

blabla: cdb supports plugins and this !analyze one is an example of something that you would expect to work but its not.

```
0:003> !analyze -v
WARNING: Teb 3 pointer is NULL - defaulting to 00000000`7ffde000
WARNING: 00000000`7ffde000 does not appear to be a TEB
ERROR: FindPlugIns 8007007b
*******************************************************************************
*                                                                             *
*                        Exception Analysis                                   *
*                                                                             *
*******************************************************************************

WARNING: Teb 3 pointer is NULL - defaulting to 00000000`7ffde000
WARNING: 00000000`7ffde000 does not appear to be a TEB
WARNING: Teb 3 pointer is NULL - defaulting to 00000000`7ffde000
WARNING: 00000000`7ffde000 does not appear to be a TEB
WARNING: Teb 3 pointer is NULL - defaulting to 00000000`7ffde000
WARNING: 00000000`7ffde000 does not appear to be a TEB
```

## DotExcrement

```
0:003> .excr
rax=0000000000000000 rbx=0000000000000000 rcx=000001ed3111e6c0
rdx=000001ed3112d3b0 rsi=0000000000000000 rdi=0000000000000001
rip=00007fff912bb796 rsp=0000003875dff640 rbp=0000000000000000
 r8=000001ed30f70040  r9=0000003875adf000 r10=0000000000000000
r11=0000000000000246 r12=0000000000000000 r13=0000000000000000
r14=0000000000000000 r15=0000000000000000
iopl=0         nv up ei pl nz na pe nc
cs=0033  ss=002b  ds=002b  es=002b  fs=0053  gs=002b             efl=00010202
r_cons+0xb796:
00007fff`912bb796 488b08          mov     rcx,qword ptr [rax] ds:00000000`00000000=????????????????
0:003> kb
  *** Stack trace for last set context - .thread/.cxr resets it
RetAddr               : Args to Child                                                           : Call Site
00000000`00000000     : 00000000`00000000 00000000`00000000 00000000`00000000 00000000`00000000 : r_cons+0xb796
0:003> kp
  *** Stack trace for last set context - .thread/.cxr resets it
Child-SP          RetAddr               Call Site
00000038`75dff640 00000000`00000000     r_cons+0xb796
0:003> kv
  *** Stack trace for last set context - .thread/.cxr resets it
Child-SP          RetAddr               : Args to Child                                         
```

Oh great finally we got the RIP value properly set, so let's check the disassembly and compare that with the binary, because for reasons we dont have any source-line information here.

To disassemble we have to use the 'u' command (unassembling) because the 'd' command was used for dumping memory in hexadecimal.

```
0:003> u rip
r_cons+0xb796:
00007fff`912bb796 488b08          mov     rcx,qword ptr [rax]
00007fff`912bb799 e8c2c2ffff      call    r_cons+0x7a60 (00007fff`912b7a60)
00007fff`912bb79e 90              nop
00007fff`912bb79f 4883c428        add     rsp,28h
00007fff`912bb7a3 c3              ret
00007fff`912bb7a4 cc              int     3
00007fff`912bb7a5 cc              int     3
00007fff`912bb7a6 cc              int     3
0:003> kb
  *** Stack trace for last set context - .thread/.cxr resets it
RetAddr               : Args to Child                                                           : Call Site
00000000`00000000     : 00000000`00000000 00000000`00000000 00000000`00000000 00000000`00000000 : r_cons+0xb796
0:003> u rip-10
r_cons+0xb786:
00007fff`912bb786 488b142558000000 mov     rdx,qword ptr [58h]
00007fff`912bb78e 488b0cca        mov     rcx,qword ptr [rdx+rcx*8]
00007fff`912bb792 488b0401        mov     rax,qword ptr [rcx+rax]
00007fff`912bb796 488b08          mov     rcx,qword ptr [rax]
00007fff`912bb799 e8c2c2ffff      call    r_cons+0x7a60 (00007fff`912b7a60)
00007fff`912bb79e 90              nop
00007fff`912bb79f 4883c428        add     rsp,28h
00007fff`912bb7a3 c3              ret
0:003>
```

## Finding the right line with radare2

We have a good starting point now! We know:

* The crash is because of a null dereference in `mov rcx, qword ptr[rax]`
* This is located around `r_cons+0xb786`

The function don't even have a name, and we dont have source line information, but at least we know the base address where the library was mapped and the instructions affected. Let's jump into r2 to find out more details!

```
C:\Users\pancake\prg\radare2\prefix\bin> radare2.exe r_cons.dll
[0x180057df0]> /x 488b142558000000488b0cca488b0401488b08
0x18000b7c7 hit0_0 488b142558000000488b0cca488b0401488b08
[0x180057df0]> s hit0_0
```

Scrolling up we find the begining of the function, which is nameless:

```
[0x18000b790]> pdf
/ 85: fcn.18000b790 (int64_t arg1);
| `- args(rcx) vars(1:sp[0x20..0x20])
|           0x18000b790      894c2408       mov dword [var_8h], ecx    ; arg1
|           0x18000b794      4883ec28       sub rsp, 0x28
|           0x18000b798      b820000000     mov eax, 0x20              ; 32
|           0x18000b79d      8bc0           mov eax, eax
|           0x18000b79f      8b0dab190600   mov ecx, dword [0x18006d150] ; [0x18006d150:4]=0
|           0x18000b7a5      65488b1425..   mov rdx, qword gs:[0x58]
|           0x18000b7ae      488b0cca       mov rcx, qword [rdx + rcx*8]
|           0x18000b7b2      48833c0800     cmp qword [rax + rcx], 0
|       ,=< 0x18000b7b7      7427           je 0x18000b7e0
|       |   0x18000b7b9      b820000000     mov eax, 0x20              ; 32
|       |   0x18000b7be      8bc0           mov eax, eax
|       |   0x18000b7c0      8b0d8a190600   mov ecx, dword [0x18006d150] ; [0x18006d150:4]=0
|       |   0x18000b7c6  ~   65488b1425..   mov rdx, qword gs:[0x58]
|       |   ;-- hit0_0:
..
|       |   0x18000b7cf      488b0cca       mov rcx, qword [rdx + rcx*8]
|       |   0x18000b7d3      488b0401       mov rax, qword [rcx + rax]
|       |   0x18000b7d7      488b08         mov rcx, qword [rax]
|       |   0x18000b7da      e881c2ffff     call sym.r_cons.dll_r_cons_context_break
|       |   0x18000b7df      90             nop
|       `-> 0x18000b7e0      4883c428       add rsp, 0x28
\           0x18000b7e4      c3             ret
[0x18000b790]>
```

But... who's calling that? let's run some analysis and check the xrefs:

```
[0x18000b790]> /r $$
(nofunc) 0x18000bf44 [CALL] call fcn.18000b790
[0x18000b790]> sf..bf44
[0x18000bf30]> pdf
/ 65: fcn.18000bf30 (int64_t arg1);
| `- args(rcx) vars(1:sp[0x20..0x20])
|           0x18000bf30      894c2408       mov dword [var_8h], ecx    ; arg1
|           0x18000bf34      4883ec28       sub rsp, 0x28
|           0x18000bf38      837c243000     cmp dword [var_8h], 0
|       ,=< 0x18000bf3d      752b           jne 0x18000bf6a
|       |   0x18000bf3f      b902000000     mov ecx, 2
|       |   0x18000bf44      e847f8ffff     call fcn.18000b790
|       |   0x18000bf49      b902000000     mov ecx, 2
|       |   0x18000bf4e      ff1584e90400   call qword [sym.imp.ucrtbased.dll___acrt_iob_func] ; [0x18005a8d8:8]=0x63996 reloc.ucrtbased.dll___acrt_iob_func
|       |   0x18000bf54      488d156587..   lea rdx, str.ctrlc_pressed._n ; 0x1800646c0 ; "{ctrl+c} pressed.\n"
|       |   0x18000bf5b      488bc8         mov rcx, rax
|       |   0x18000bf5e      e85d050000     call 0x18000c4c0
|       |   0x18000bf63      b801000000     mov eax, 1
|      ,==< 0x18000bf68      eb02           jmp 0x18000bf6c
|      |`-> 0x18000bf6a      33c0           xor eax, eax
|      |    ; CODE XREF from fcn.18000bf30 @ 0x18000bf68(x)
|      `--> 0x18000bf6c      4883c428       add rsp, 0x28
\           0x18000bf70      c3             ret
[0x18000bf30]>
```

Perfect we have a string here! grepping the source code we find this code:

```
C:\Users\pancake\prg\radare2>git grep "} pressed"
libr/cons/cons.c:               eprintf ("{ctrl+c} pressed.\n");
```

Let's open this file in vim and see what's going on, and what's that `eprintf`.

```c
static R_TH_LOCAL RCons *I = NULL;

static BOOL __w32_control(DWORD type) {
        if (type == CTRL_C_EVENT) {
                __break_signal (2); // SIGINT
                eprintf ("{ctrl+c} pressed.\n");
                return true;
        }
        return false;
}
static void __break_signal(int sig) {
        r_cons_context_break (I->context);
}
```

Bingo, now we have the reason of that null deref. Seems like `I` is NULL, so we can fix the problem by adding a simple if(I) guard and solve the crash when the user pressed `^C`.

## Understanding

Unix signals and Windows Exception handlers cannot take any parameter for context/userdata. This is pretty bad because forces use to use global variables.

In order to tell r2 which console received the sigint handler we need to basically set a global pointer before setting the event handler. But.. why this worked on UNIX and not on WIndows?

Turns out that windows `CTRL_C_EVENT` handler is executed from a different thread! which means that the `I` variable wasn't initialized because that's a thread-local variable.

`R_TH_LOCAL` is a portability alias for r2 to specify which global variables must be stored in the `_Thread_Local` attribute.

## Final words

Ideally we may want to have multiple RCons instances to use a single terminal, it's not just that you can have a single core associated to one rcons instance to run from different threads. But also that you can have multiple threads having its own separate RCore instances each of them with each own RCons.

Who may receive the event? All of them? The last one to request the interruption? Can RCons instances stop being affected by those events?

What's clear is that such interruptions can happen at any time and from any thread and can affect data from any random process. Mixing that with the fact that we must use global variables adds more pain to the recipe. But well, that's a story for another post.

Hope you learned some stuff and as a unix lover lost a little of fear to use windows from the good old cmd terminal.

--pancake
