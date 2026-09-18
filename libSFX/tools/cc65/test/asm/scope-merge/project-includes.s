        .include "consts-first.inc"
        .include "consts-second.inc"

        .byte   PROJECTNAME::HARDWARE::CHIP
        .byte   PROJECTNAME::SOFTWARE::VERSION
        .byte   PROJECTNAME::HARDWARE::PCB
        .byte   PROJECTNAME::SOFTWARE::FLAGS

        .assert PROJECTNAME::HARDWARE::CHIP = $0F, error, "CHIP is incorrect"
        .assert PROJECTNAME::HARDWARE::PCB = $0E, error, "PCB is incorrect"
        .assert PROJECTNAME::SOFTWARE::VERSION = $01, error, "VERSION is incorrect"
        .assert PROJECTNAME::SOFTWARE::FLAGS = $02, error, "FLAGS are incorrect"
