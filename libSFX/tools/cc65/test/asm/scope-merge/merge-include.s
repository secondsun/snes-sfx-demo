        .scope  included
first:  .byte   $11
        .endscope

        .include "merge-include.inc"

        .assert included::second - included::first = 1, error, "symbols are incorrect"
        .assert .sizeof(included) = 3, error, "included scope size is incorrect"
