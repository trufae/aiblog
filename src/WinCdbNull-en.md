# Fixing a Radare2 bug from the Windows Cmd

- **Published:** November 23, 2025
- **Author:** pancake

---

## Introduction

It's widely known that debugging programs on Windows is a pain—and even more so if you come from Unix. The main reason is because there is no good command line tooling and the cmd.exe as well as the PowerShell are pretty far from the usability of a POSIX shell.

It also feels weird with all those random NT APIs that usually look alien to a Unix person and they are bloated with tons of ways to achieve the same thing and it's designed to be primarily designed to use it from graphical apps.

Luckily, Microsoft has improved support for command-line and Unix integration since 2020. They added C99 support for the compiler (about time!), shipped WSL by default, empowered PowerShell to make malware authors more imaginative than with the poor cmd.exe batch scripting, and also added more command-line utilities to administer Windows systems through SSH.

Windows users are used to depending on bloated graphical apps that take up dozens of GBs, like Visual Studio, just to get a backtrace—and if that wasn't painful enough, you are forced to use the mouse.

In this blog post, I will explain how I fixed the bug in Radare2 using only the Windows CMD shell.

## Building from git

Building Radare2 from Git is the recommended way to install it, primarily for developing and testing. On Unix systems, that's a common workflow, and it's as easy as running ./sys/install.sh (which runs ./configure + make + make symstall), but there's also support for meson+ninja, which is what's used on Windows.

To simplify all these, Radare comes with a bunch of batch scripts that are in the root directory of the project. The first one is pre-configure.bat, then you have configure.bat and make.bat. So the first one, set up the environment, because obviously Windows won't make things easier and won't put the compiler and linker in your path even if you have Visual Studio installed.

This script sets up the whole build environment on Windows. It finds the right version of Python, creates a virtual environment to install Meson and Ninja, finds Visual Studio and the Windows Debugger SDK, and puts everything in PATH for you to use.

I also installed `vim`, but if you are fine with `edit.com` I won't judge you.

When you run `make.bat`, it will execute Meson and Ninja to compile the project, placing the final binaries, pdb files (the Windows version of dwarf), libraries and companion files into the `.\prefix` directory.

Just `cd .\prefix\bin`, and you're all good to go—run `radare2.exe rax2.exe` to test it!

## Spotting the bug

Right before every release, I try my best to test Radare2 as much as possible on all imaginable platforms and architectures—and unfortunately, Windows is also in that list.

The CI tests commands, unit API behaviors, assemblers, disassemblers, parsing fuzzed binaries and filesystems, but none of this can cover what the end user would experience when running it, entering visual mode, using the debugger, etc.

It takes some time to build by hand on every architecture and operating system and test everything. The first thing I tried in this build was to perform a full analysis on the `rax2.exe` binary with the `aaaa` command. As this took a long time, I just pressed Ctrl-C and unexpectedly was kicked back to the system prompt.

This means that Radare2 exited instead of canceling the analysis.

## Error Codes

Wait, that doesn't make any sense. Control-C shouldn't be leaving the program! I would expect a popup with a crash log message, or a 'Segmentation Fault' in the console. But Windows programs crash so often that doing such things would worry their users, and all that stuff is hidden!

To find out what happened, we need to `echo %ERRORLEVEL%` to find out the return code of the program. Yes, the number that the main function returns to the system is also used to inform about crash exceptions.

It should be just stopping the process because Radare2 is actually hooking into the Control-C event. So in order to understand what was going on—because Windows CMD won't tell you if the program has crashed, failed, or was just exiting—(sidenote: this was fixed in PowerShell; we're just having fun in cmd.exe, remember?)

```console
C:\radare2\prefix\bin> radare2.exe rax2.exe
C:\radare2\prefix\bin> echo %ERRORLEVEL%
-1073741819
```

And then you get a negative number, which obviously makes no sense. Translating it to hexadecimal may help:

We can also learn from other common easy to remember negative numbers:

```console
$ rax2 -1073741819 -1073741510 -1073740791
0xc0000005
0xc000013a
0xc0000409
```

* -1073741819 = Segmentation Fault (SIGSEGV)
* -1073741510 = Process Interrupted (SIGINT)
* -1073740791 = Stack Overflow

Therefore, in this case, we got a segmentation fault.

## Coredumps

We now know that was a segmentation fault, but we don't know where. So in order to do that, we can check in our users' crash dump directory. These `.dmp` files are the same as `coredumps` on the Unix world.

```console
C:\Users\pancake\AppData\Local\CrashDumps>copy radare2.exe.12964.dmp C:\users\pancake\prg\radare2\prefix\bin
```

A summary can be read from the system logs using the wevtutil tool:

```console
C:\Users\pancake\prg\radare2\prefix\bin>wevtutil qe Application /q:"*[System[(Level=2) and (Provider[@Name='Application Error'])]]" /f:text /c:5

Listing package-relative application ID:

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

In this crash log, we see that the radare2.exe program was executed. It was failing in ucrtbased.dll, which is the Windows libc, but we know nothing more—no backtrace, no symbol names, nothing.

## Debugging

This brings us to the very next logical step: debugging.

Debugging on Windows is a very painful experience. Because we don't have GDB/LLDB and the x64dbg and VS solutions rely on a pointer device like a mouse or touchpad. Our brain is wired to a keyboard and moving the hands away hurts.

Luckily for me I learned about `CDB`, the console debugger from the Windows Debug SDK, which can be downloaded from the official Microsoft page:

* [https://developer.microsoft.com/en-us/windows/downloads/windows-sdk/](https://developer.microsoft.com/en-us/windows/downloads/windows-sdk/)

Obviously Windows won't make things easier, and cdb won't be in the PATH either, but radare2's `preconfigure.bat` will cover you and silently do it for you.

CDB feels like `debug.com` in the good old DOS times. It's direct, clear, and easy to use. Having mnemonic commands to run actions and extensible through scripts like `!analyze`, it is able to load crash dumps, spawn programs, attach to processes, display backtraces, and keep exceptions and things like that.

These are the common commands you need to use to list processes or attach/spawn for debugging:

* tasklist -> like `ps`
* debugging cdb radare2 rax2.exe -> ^C captured by cdb, not r2, cant repro
* attach with cdb -p pid

## Exceptions

Exception events—so even if we tell CDB to ignore the ^C event, it just hooks it and prints a message, but the null exception doesn't trigger. We will need to check the crash dump.

The first thing I tried was to spawn Radare2 within CDB and trigger the `Ctrl+C`, but that got me back to the CDB shell, because the debugger captured the exception event. Similar behavior we have in GDB/LLDB/R2 when debugging in the very same terminal.

So I tried attaching: starting radare2 in a separate `cmd.exe` console, picking the PID with `tasklist`, and attaching using `cdb -p pid`. But this time, I was ready to ignore the CTRL-C event using the `sxn` command:

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

The sxn command basically allows you to skip the exception handler—the process was not interrupted, and the debugger was informing me about the event, but the crash didn't happen, which means the original exception handler was not executed. That was a fun but useless approach.

## Minidump

Let's go try the post-mortem analysis approach. Using the `-z` flag of `cdb` I could load the `.dmp` file:

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

Lots more information than I expected—and actually kind of useless, because all the register values are zero, no backtrace again. So I guess I missed a step, because Windows must be frustrating by default. Better to take a break and learn a little about CDB:

## The CDB Shell

These are some of the most common commands we will need:

* u ; unassemble
* r ; regs
* d ; dump
* g ; go (aka run / continue)
* kb ; backtrace basic
* kp ; backtrace with parameters
* kv ; backtrace verbose

Typing the `?` command will give us a more complete listing:

```console
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

This bad boy also supports plugins. There is the '!analyze' plugin that basically runs a bunch of commands and analyzes the code and the backtrace to show you a useful report that you can use to understand why the program failed. The thing is that, as you might expect, this analyze script is basically useless.

Unfortunately, it shows nothing more than just the null dereference and a lot of useless, repetitive messages saying nothing. So I will need to dig a little bit more.

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

As Windows and all the debugging environment are pure shit, CDB comes with an excrement command (`.excr`). Which basically loads the last exception crash state into the running session, allowing us to finally see some useful information. Thanks to that you get the register values, the address of the program content, and you can basically analyze and disassemble.

Well, actually 'unassemble' because they used the U command to disassemble (since D was taken for hexdumps). And we end up finding out that this 'mov rcx' instruction is the one that's causing the crash, and everything is failing inside the r_cons library.

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

We got the RIP value, finally! Let's check the disassembly and compare that with the binary to find out the function name and associated source line. Because... guess what—even if the `.pdb` files are in the very same directory as the executables, `cdb` won't be loading them unless we specify the path using the `.sympath` command and then hit the `.reload` command. But I'm old for all this, so I will just go read the assembly.

```console
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

We have a good starting point now. We know:

* The crash is because of a null dereference in `mov rcx, qword ptr[rax]`
* This is located around `r_cons+0xb786`

The function doesn't even have a name, and we don't have source line information, but at least we know the base address where the library was mapped and the instructions affected. Let's jump into r2 to find out more details!

```
C:\Users\pancake\prg\radare2\prefix\bin> radare2.exe r_cons.dll
[0x180057df0]> /x 488b142558000000488b0cca488b0401488b08
0x18000b7c7 hit0_0 488b142558000000488b0cca488b0401488b08
[0x180057df0]> s hit0_0
```

Scrolling up, we find the beginning of the function, which is nameless:

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

But... who's calling that? Let's run some analysis and check the xrefs:

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

Perfect, we have a string here! Grepping the source code, we find this code:

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

Bingo, now we have the reason for that null dereference. Seems like the `I` global variable is NULL, so we can fix the problem by adding a simple if(I) guard and solve the crash when the user presses `^C`.

## Understanding

Unix signals and Windows exception handlers cannot take any parameter for context/userdata. This is pretty bad because it forces us to use global variables.

In order to tell r2 which console received the sigint handler we need to basically set a global pointer before setting the event handler. But.. why this worked on UNIX and not on Windows?

Turns out that the Windows `CTRL_C_EVENT` handler is executed from a different thread! Which means that the `I` variable wasn't initialized because that's a thread-local variable.

`R_TH_LOCAL` is a portability alias for r2 to specify which global variables must be stored in the `_Thread_Local` attribute.

## Final words

Ideally, we may want to have multiple RCons instances to use a single terminal—it's not just that you can have a single core associated with one RCons instance to run from different threads. But also, you can have multiple threads having their own separate RCore instances, each with their own RCons.

Who may receive the event? All of them? The last one to request the interruption? Can RCons instances stop being affected by those events?

What's clear is that such interruptions can happen at any time and from any thread and can affect data from any random process. Mixing that with the fact that we must use global variables adds more pain to the recipe. But well, that's a story for another post.

Hope you learned some stuff and, as a Unix lover, lost a little fear of using Windows from the good old CMD terminal.

--pancake
