; Output: [E820_COUNT] = number of valid entries (dword)
;         entries at E820_ENTRIES, 24 bytes each: base(8) length(8) type(4) attrs(4)
; Returns: CF clear on success, CF set on failure
; Clobbers: eax, ebx, ecx, edx, di, bp. ES is preserved. Requires DS = 0.

E820_COUNT   equ 0x6000     ; dword: number of entries, written once at the end
E820_ENTRIES equ 0x6008     ; first entry, 8-byte aligned
E820_ENTSIZE equ 24         ; size of each entries 24 bytes
E820_MAX     equ 64         ; stop the loop here
E820_SMAP    equ 0x534D4150 ; SMAP Magic number

do_e820:
    push es
    xor ax, ax
    mov es, ax           ; es = 0 so es:di is the physical address
    mov di, E820_ENTRIES
    xor ebx, ebx         ; continuation value, 0 for the first call
    xor bp, bp           ; count of valid entries

.next:
    mov  dword [es:di + 20], 1      ; ACPI 3.0 attrs = 1 in case BIOS returns 20 bytes
    mov  eax, 0xE820                ; reloaded every call (BIOS returns SMAP in eax)
    mov  ecx, E820_ENTSIZE
    mov  edx, E820_SMAP
    int  0x15
    jc   .carry                     ; carry: unsupported, or past the last entry
    cmp  eax, E820_SMAP
    jne  .error                     ; BIOS did not echo the signature
    test cl, cl
    jz   .check_end                 ; 0 bytes stored: skip
    mov  eax, [es:di + 8]           ; length, low dword
    or   eax, [es:di + 12]          ; length, high dword
    jz   .check_end                 ; length 0: skip, do not advance DI
    add  di, E820_ENTSIZE           ; valid entry: next slot
    inc  bp
    cmp  bp, E820_MAX
    jae  .done                      ; buffer full

.check_end:
    test ebx, ebx
    jnz  .next                      ; ebx != 0: more entries

.done:
    test bp, bp
    jz   .error                     ; no valid entry at all
    movzx eax, bp
    mov  [E820_COUNT], eax          ; DS = 0, so this is physical 0x6000
    pop  es
    clc
    ret

.carry:
    test bp, bp
    jnz  .done                      ; carry after valid entries = end of list

.error:
    pop es
    stc
    ret
