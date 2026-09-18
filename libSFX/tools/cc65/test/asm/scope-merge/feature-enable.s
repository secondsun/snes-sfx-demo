        .feature merge_scopes

        .scope  feature_scope
first = 1
        .endscope

        .scope  feature_scope
second = 2
        .endscope

        .assert feature_scope::first = 1, error, "first symbol is missing"
        .assert feature_scope::second = 2, error, "second symbol is missing"
