        .scope  merged
first:  .byte   $11
        .endscope

        .byte   $FF

        .scope  merged
second: .byte   $22, $33
        .endscope

        .assert merged::second - merged::first = 2, error, "symbols are incorrect"
        .assert .sizeof(merged) = 3, error, "merged scope size is incorrect"
