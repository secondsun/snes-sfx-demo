        .scope  outer
        .scope  inner
first:  .byte   $11
        .endscope
        .endscope

        .scope  outer
        .scope  inner
second: .byte   $22
        .endscope
        .endscope

        .assert outer::inner::second - outer::inner::first = 1, error, "symbols are incorrect"
        .assert .sizeof(outer::inner) = 2, error, "inner scope size is incorrect"
        .assert .sizeof(outer) = 2, error, "outer scope size is incorrect"
