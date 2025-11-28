# Arreglant un error de Radare2 des del Cmd de Windows

- **Publicat:** 23 de novembre de 2025
- **Autor:** pancake

---

## Introducció

Per mi, sempre m'ha semblat dolorós depurar programes en Windows, principalment perquè vinc acostumat de treballar en entorns UNIX. La queixa principal que tinc és que no hi ha bones terminals ni eines per la shell, malgrat powershell sigui una millora substancial en quant a consistència, no deixa d'estar bastant lluny de la usabilitat d'una terminal POSIX.

Amb totes les APIs NT amb noms confusos no ajuden a millorar l'experiència, a més està dissenyat per fer-lo anar de forma gràfica i no porto gaire bé això d'anar treient una ma del teclat cada dos per tres per moure el ratolí.

Per sort, Microsoft ha millorat el suport per a la línia d'ordres i la integració amb Unix. Ben entrat a 2020, van afegir suport C99 (estandard de C de 1999), han afegit WSL per defecte, han facilitat l'us de malware gràcies a l'scripting amb PowerShell i també han afegit moltes utilitats de línia d'ordres per administrar sistemes Windows a través de SSH.

Malgrat tot això, els usuaris de Windows estan acostumats a dependre d'aplicacions gràfiques que ocupen desenes de GB en disc i memòria, i triguen en arrencar, si, estic pensant en tu Visual Studio.. per accions com obtenir un backtrace.

Així doncs, m'agradaria compartir la meva experiència de tot plegat en aquest article on explicaré com vaig arreglar un error a Radare utilitzant només la consola CMD de Windows.

## Compilant des de git

Sempre recomano compilar Radare2 des de Git, no només per desenvolupar sino també per provar els ultims canvis. En sistemes Unix, aquest és comú compilar-ho tot, i en radare2 és tan senzill com `./sys/install.sh` (que executa `./configure+make+make symstall`), però també hi ha suport per a meson+ninja, que és el que s'utilitza a Windows.

Per simplificar tot això, Radare vé amb un grapat d'scripts batch pel cmd de Windows que es troben al directori arrel del projecte. El primer és `preconfigure.bat`, `configure.bat` i `make.bat`. Executal's en ordre per configurar l'entorn, el project i compilar-lo.

El primer script configura tot l'entorn de compilació a Windows, busca la versió de Python, crea un entorn virtual per instal·lar meson i ninja, troba Visual Studio i el Windows Debugger SDK i ho posa tot al PATH perquè ho puguis utilitzar.

Jo sempre instal·lo `vim`, però si et conformes amb `edit.com` no et jutjaré.

Quan executes `make.bat`, s'executarà Meson i Ninja per compilar el projecte, col·locant els binaris finals, els fitxers pdb (la versió de Windows de dwarf), les llibreries i els fitxers complementaris al directori `.\prefix`.

Només has de fer `cd .\prefix\bin` i ja estàs a punt per executar `radare2.exe` i `rax2.exe` per provar-ho!

## Detectant l'error

Just abans de cada llançament, intento provar radare tant com puc i en totes les plataformes i arquitectures imaginables, i malauradament, Windows també està en aquesta llista.

Les ordres de prova d'integració contínua, comportaments unitaris de l'API, assembladors, desassembladors, anàlisi de binaris i sistemes de fitxers "fuzzed", però res d'això pot cobrir el que l'usuari final experimentaria en executar-lo, entrar en mode visual, utilitzar el depurador, etc.

Porta una estona compilar a mà a cada arquitectura, cada sistema operatiu i provar-ho tot. El primer que vaig provar en aquesta compilació va ser realitzar una anàlisi completa del binari `rax2.exe` amb l'ordre `aaaa`. Com que això va trigar molt, vaig prémer Ctrl+C i inesperadament vaig tornar a la línia d'ordres del sistema.

Això significa que radare va sortir en lloc de cancel·lar l'anàlisi.

## Codis d'Error

Espera, això no té cap sentit. Control-C no hauria de fer sortir del programa! Esperaria una finestra emergent amb un missatge de fallada, o un "Segmentation Fault" a la consola. Però els programes de Windows fallen tan sovint, que fer aquestes coses preocuparia els seus usuaris i tot això s'amaga!

Per saber què va passar, necessitem fer `echo %ERRORLEVEL%`, per descobrir el codi de retorn del programa. Sí, el número que la funció main retorna al sistema també s'utilitza per informar sobre excepcions de fallada.

Hauria de limitar-se a aturar el procés perquè Radare en realitat està capturant l'esdeveniment de Control-C. Així que per entendre què passava, perquè el CMD de Windows no et dirà si el programa ha fallat, ha petat o simplement ha executat un exit. (Nota al marge: això es va solucionar a PowerShell, només ens estem divertint amb cmd.exe, recordeu?)

```console
C:\radare2\prefix\bin> radare2.exe rax2.exe
C:\radare2\prefix\bin> echo %ERRORLEVEL%
-1073741819
```

I llavors obtens un número negatiu, que òbviament no té sentit. Traduir-lo a hexadecimal pot ajudar:

També podem aprendre d'altres números negatius comuns i fàcils de recordar:

```console
$ rax2 -1073741819 -1073741510 -1073740791
0xc0000005
0xc000013a
0xc0000409
```

* -1073741819 = Fallada de segmentació (SIGSEGV)
* -1073741510 = Procés interromput (SIGINT)
* -1073740791 = Desbordament de pila

Per tant, en aquest cas, hem tingut una fallada de segmentació.

## Bolcats de memòria (Coredumps)

Ara sabem que va ser una fallada de segmentació, però no sabem on. Per fer-ho, podem comprovar el directori de bolcats de fallades del nostre usuari. Aquests fitxers `.dmp` són el mateix que els `coredumps` al món UNIX.

```console
C:\Users\pancake\AppData\Local\CrashDumps>copy radare2.exe.12964.dmp C:\users\pancake\prg\radare2\prefix\bin
```

Es pot llegir un resum dels registres del sistema utilitzant l'eina wevtutil:

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

En aquest registre de fallada, veiem que es va executar el programa radare2.exe. Estava fallant a ucrtbased.dll, que és la libc de Windows, però no en sabem res més, ni backtrace, ni noms de símbols, res.

## Depurant

Això ens porta al següent pas lògic: la depuració.

Depurar a Windows és una experiència molt penosa. Perquè no tenim GDB/LLDB i les solucions x64dbg i VS depenen d'un dispositiu apuntador com un ratolí o un touchpad. El nostre cervell està connectat a un teclat i allunyar les mans fa mal.

Per sort per a mi, vaig descobrir `CDB`, el depurador de consola del Windows Debug SDK, que es pot descarregar des de la pàgina oficial de Microsoft:

* [https://developer.microsoft.com/en-us/windows/downloads/windows-sdk/](https://developer.microsoft.com/en-us/windows/downloads/windows-sdk/)

Òbviament, Windows no posarà les coses fàcils, i cdb tampoc estarà al PATH, però el `preconfigure.bat` de radare2 et cobrirà les espatlles i ho farà per tu silenciosament.

`CDB` se sent com `debug.com` en els vells temps de DOS. És directe, clar i fàcil d'utilitzar. Amb ordres mnemotècniques per executar accions i extensible a través de scripts com `!analyze`, és capaç de carregar bolcats de fallades, llançar programes, adjuntar-se a processos, mostrar backtraces i gestionar excepcions i coses per l'estil.

Aquestes són les ordres comunes que necessites utilitzar per llistar processos o adjuntar/llançar per depurar:

* tasklist -> com `ps`
* depurar cdb radare2 rax2.exe -> ^C capturat per cdb, no per r2, no es pot reproduir
* adjuntar amb cdb -p pid

## Excepcions

Esdeveniments d'excepció, així que fins i tot si li diem a cdb que ignori l'esdeveniment ^C, simplement el captura i imprimeix un missatge, però l'excepció nul·la no s'activa... haurem de comprovar el bolcat de fallada.

El primer que vaig intentar va ser llançar Radare dins de CDB i prémer `Ctrl+C`, però això em va tornar a la consola de CDB, perquè el depurador va capturar l'esdeveniment d'excepció. Un comportament similar tenim a GDB/LLDB/R2 quan depurem en el mateix terminal.

Així que vaig provar d'adjuntar, iniciant radare2 en una consola `cmd.exe` separada, agafant el PID amb `tasklist` i adjuntant amb `cdb -p pid`, però aquesta vegada estava preparat per ignorar l'esdeveniment CTRLC utilitzant l'ordre `sxn`:

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

L'ordre sxn bàsicament et permet saltar el gestor d'excepcions, el procés no es va interrompre, i el depurador m'informava de l'esdeveniment, però la fallada no va passar, el que significa que el gestor d'excepcions original no es va executar. Va ser un enfocament divertit i inútil.

## Minidump

Anem a provar l'enfocament d'anàlisi post-mortem. Utilitzant l'indicador `-z` de `cdb` puc carregar el fitxer `.dmp`:

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

Molta més informació de la que esperava, i en realitat bastant inútil perquè tots els valors dels registres són zero, i de nou cap backtrace. Suposo que m'he saltat un pas perquè Windows ha de ser frustrant per defecte, així que millor fer una pausa i aprendre una mica de CDB:

## La consola de CDB

Aquestes són algunes de les ordres més comunes que necessitarem:

* u ; desassemblar
* r ; registres
* d ; bolcar
* g ; anar (també conegut com executar / continuar)
* kb ; backtrace bàsic
* kp ; backtrace amb paràmetres
* kv ; backtrace verbós

Teclejant l'ordre `?` ens donarà una llista més completa:

```console
0:001> ?

Obre debugger.chm per a la documentació completa del depurador

B[C|D|E][<bps>] - esborrar/desactivar/activar punt(s) de ruptura
BL - llistar punts de ruptura
BA <access> <size> <addr> - establir punt de ruptura de processador
BP <address> - establir punt de ruptura de programari
D[type][<range>] - bolcar memòria
DT [-n|y] [[mod!]name] [[-n|y]fields]
   [address] [-l list] [-a[]|c|i|o|r[#]|v] - bolcar usant informació de tipus
DV [<name>] - bolcar variables locals
DX [-r[#]] <expr> - mostrar expressió C++ usant el model d'extensió (p. ex.: NatVis)
E[type] <address> [<values>] - introduir valors de memòria
G[H|N] [=<address> [<address>...]] - anar
K <count> - traça de pila
KP <count> - traça de pila amb arguments de codi font
LM[k|l|u|v] - llistar mòduls
LN <expr> - llistar símbols més propers
P [=<addr>] [<value>] - pas per sobre
Q - sortir
R [[<reg> [= <expr>]]] - veure o establir registres
S[<opts>] <range> <values> - cercar a la memòria
SX [{e|d|i|n} [-c "Cmd1"] [-c2 "Cmd2"] [-h] {Exception|Event|*}] - filtre d'esdeveniments
T [=<address>] [<expr>] - traçar dins
U [<range>] - desassemblar
version - mostrar versió del depurat i depurador
X [<*|module>!]<*|symbol> - veure símbols
? <expr> - mostrar expressió
?? <expr> - mostrar expressió C++
$< <filename> - prendre l'entrada d'un fitxer d'ordres

<expr> operadors unaris: + - not by wo dwo qwo poi hi low
       operadors binaris: + - * / mod(%) and(&) xor(^) or(|)
       comparacions: == (=) < > !=
       operands: número en la base actual, símbol públic, <reg>
<type> : b (byte), w (word), d[s] (doubleword [amb símbols]),
         a (ascii), c (dword i Char), u (unicode), l (llista)
         f (float), D (double), s|S (cadena ascii/unicode)
         q (quadword)
<pattern> : [(nt | <dll-name>)!]<var-name> (<var-name> pot incloure ? i *)
<range> : <address> <address>
        : <address> L <count>

Opcions de mode d'usuari:
~ - llistar l'estat dels fils
~#s - establir fil per defecte
| - llistar l'estat dels processos
|#s - establir procés per defecte

Opcions x64:
DG <selector> - bolcar selector
<reg> : [r|e]ax, [r|e]bx, [r|e]cx, [r|e]dx, [r|e]si, [r|e]di, [r|e]bp, [r|e]sp, [r|e]ip, [e]fl,
        r8-r15 amb subregistres b/w/d
        al, ah, bl, bh, cl, ch, dl, dh, cs, ds, es, fs, gs, ss
        sil, dil, bpl, spl
        dr0, dr1, dr2, dr3, dr6, dr7
        fpcw, fpsw, fptw, st0-st7, mm0-mm7
         xmm0-xmm15
<flag> : iopl, of, df, if, tf, sf, zf, af, pf, cf
<addr> : #<adreça de mode protegit de 16 bits [seg:]>,
         &<adreça de mode V86 [seg:]>

Obriu debugger.chm per a la documentació completa del depurador

0:001>
```

## Plugins de Cdb

Aquesta mala bèstia també suporta plugins. Hi ha el plugin "!analyze" que bàsicament executa un grapat d'ordres i analitza el codi i el backtrace per mostrar-te un informe útil que pots fer servir per entendre per què el programa ha fallat. La qüestió és que, com era d'esperar, aquest script d'anàlisi és bàsicament inútil.

Malauradament, no mostra res més que la desreferència nul·la i un munt de missatges repetitius inútils que no diuen res. Així que hauré de cavar una mica més.

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

## El punt Excrement

Com que Windows i tot l'entorn de depuració són pura merda, Cdb ve amb una ordre excrement (`.excr`). Que bàsicament carrega l'últim estat de fallada d'excepció a la sessió en curs, permetent-nos finalment veure informació útil. Gràcies a això, obtens els valors dels registres, l'adreça del contingut del programa, i bàsicament pots analitzar i desassemblar.

Bé, en realitat `unassemble` perquè van utilitzar l'ordre U per desassemblar, ja que la D estava ocupada per als bolcats hexadecimals. I acabem descobrint que aquesta instrucció `mov-rcx` és la que està causant la fallada, i tot està fallant dins de la llibreria r_cons.

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

Tenim el valor de RIP, finalment! Comprovem el desassemblat i comparem-ho amb el binari per esbrinar el nom de la funció i la línia de codi font associada. Perquè... endevina què, encara que els fitxers `.pdb` estiguin al mateix directori que els executables, `cdb` no els carregarà si no especifiquem la ruta amb l'ordre `.sympath` i després executem l'ordre `.reload`. Però ja soc gran per a tot això, així que simplement llegiré l'assemblador.

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

## Trobant la línia correcta amb radare2

Ara tenim un bon punt de partida! Sabem:

* La fallada és a causa d'una desreferència nul·la a `mov rcx, qword ptr[rax]`
* Això es troba al voltant de `r_cons+0xb786`

La funció ni tan sols té un nom, i no tenim informació de la línia de codi font, però almenys sabem l'adreça base on es va mapejar la llibreria i les instruccions afectades. Anem a r2 per descobrir més detalls!

```
C:\Users\pancake\prg\radare2\prefix\bin> radare2.exe r_cons.dll
[0x180057df0]> /x 488b142558000000488b0cca488b0401488b08
0x18000b7c7 hit0_0 488b142558000000488b0cca488b0401488b08
[0x180057df0]> s hit0_0
```

Pujant amunt trobem l'inici de la funció, que no té nom:

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

Però... qui la crida? Fem una mica d'anàlisi i comprovem les referències creuades (xrefs):

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

Perfecte, tenim una cadena de text aquí! Fent un grep al codi font trobem aquest codi:

```
C:\Users\pancake\prg\radare2>git grep "} pressed"
libr/cons/cons.c:               eprintf ("{ctrl+c} pressed.\n");
```

Obrim aquest fitxer a vim i veiem què passa, i què és aquest `eprintf`.

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

Bingo, ara tenim la raó d'aquesta desreferència nul·la. Sembla que la variable global `I` és NULL, així que podem solucionar el problema afegint una simple comprovació `if(I)` i resoldre la fallada quan l'usuari prem `^C`.

## Entenent el problema

Els senyals d'Unix i els gestors d'excepcions de Windows no poden prendre cap paràmetre per a context/userdata. Això és bastant dolent perquè ens obliga a utilitzar variables globals.

Per dir-li a r2 quina consola va rebre el gestor de sigint, bàsicament necessitem establir un punter global abans de configurar el gestor d'esdeveniments. Però... per què això funcionava a UNIX i no a Windows?

Resulta que el gestor `CTRL_C_EVENT` de Windows s'executa des d'un fil d'execució diferent! La qual cosa significa que la variable `I` no estava inicialitzada perquè és una variable local al fil (`thread-local`).

`R_TH_LOCAL` és un àlies de portabilitat per a r2 per especificar quines variables globals s'han d'emmagatzemar en l'atribut `_Thread_Local`.

## Paraules finals

Idealment, voldríem tenir múltiples instàncies de RCons per utilitzar un únic terminal. No es tracta només que puguis tenir un únic nucli associat a una instància de RCons per executar des de diferents fils, sinó que també pots tenir múltiples fils amb les seves pròpies instàncies de RCore separades, cadascuna amb el seu propi RCons.

Qui pot rebre l'esdeveniment? Totes? L'última a sol·licitar la interrupció? Les instàncies de RCons poden deixar de ser afectades per aquests esdeveniments?

El que està clar és que aquestes interrupcions poden passar en qualsevol moment i des de qualsevol fil i poden afectar dades de qualsevol procés aleatori. Barrejar això amb el fet que hem d'utilitzar variables globals afegeix més dolor a la recepta. Però bé, això és una història per a una altra publicació.

Espero que hàgiu après alguna cosa i, com a amant d'Unix, hàgiu perdut una mica la por d'utilitzar Windows des del bon vell terminal cmd.

--pancake
