#include <check.h>
#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include <stdint.h>

START_TEST(test_wav_buffer_overflow_protection)
{
    // Invariant: Buffer reads never exceed the declared length
    
    typedef struct {
        uint32_t data_size;
        uint16_t block_align;
        const char *description;
    } test_payload;
    
    test_payload payloads[] = {
        {0xFFFFFFFF, 2, "max_uint32_data_size"},
        {0x7FFFFFFF, 4, "near_max_with_overflow"},
        {1024, 2, "valid_small_input"}
    };
    int num_payloads = sizeof(payloads) / sizeof(payloads[0]);

    for (int i = 0; i < num_payloads; i++) {
        char wav_file[256];
        snprintf(wav_file, sizeof(wav_file), "/tmp/test_wav_%d.wav", i);
        
        FILE *f = fopen(wav_file, "wb");
        ck_assert_ptr_nonnull(f);
        
        // WAV header
        fwrite("RIFF", 1, 4, f);
        uint32_t file_size = 36 + payloads[i].data_size;
        fwrite(&file_size, 4, 1, f);
        fwrite("WAVEfmt ", 1, 8, f);
        uint32_t fmt_size = 16;
        fwrite(&fmt_size, 4, 1, f);
        uint16_t format = 1, channels = 1, bits = 16;
        uint32_t sample_rate = 44100;
        fwrite(&format, 2, 1, f);
        fwrite(&channels, 2, 1, f);
        fwrite(&sample_rate, 4, 1, f);
        uint32_t byte_rate = sample_rate * payloads[i].block_align;
        fwrite(&byte_rate, 4, 1, f);
        fwrite(&payloads[i].block_align, 2, 1, f);
        fwrite(&bits, 2, 1, f);
        fwrite("data", 1, 4, f);
        fwrite(&payloads[i].data_size, 4, 1, f);
        fclose(f);
        
        // Execute brr_encoder with crafted WAV
        char cmd[512];
        snprintf(cmd, sizeof(cmd), "timeout 2 libSFX/tools/brrtools/brr_encoder %s /tmp/out_%d.brr 2>&1", wav_file, i);
        int result = system(cmd);
        
        // Invariant: process must not crash (segfault = 139, timeout = 124)
        ck_assert_msg(WEXITSTATUS(result) != 139 && WEXITSTATUS(result) != 124,
                      "Buffer overflow detected for payload: %s", payloads[i].description);
        
        unlink(wav_file);
    }
}
END_TEST

Suite *security_suite(void)
{
    Suite *s;
    TCase *tc_core;

    s = suite_create("Security");
    tc_core = tcase_create("Core");

    tcase_add_test(tc_core, test_wav_buffer_overflow_protection);
    suite_add_tcase(s, tc_core);

    return s;
}

int main(void)
{
    int number_failed;
    Suite *s;
    SRunner *sr;

    s = security_suite();
    sr = srunner_create(s);

    srunner_run_all(sr, CK_NORMAL);
    number_failed = srunner_ntests_failed(sr);
    srunner_free(sr);

    return (number_failed == 0) ? EXIT_SUCCESS : EXIT_FAILURE;
}