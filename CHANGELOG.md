# Roo SmarterCSV Change Log

## [1.0.0.pre2] - 2026-05-17

- Initial release

Speedup vs Roo::CSV with SmarterCSV 1.17.1

| File                           | Speedup |
| ------------------------------ | ------: |
| PEOPLE_IMPORT_B.csv            |   2.98x |
| uscities.csv                   |   4.22x |
| uszips.csv                     |   4.45x |
| worldcities.csv                |   4.58x |
| embedded_newlines_60k.csv      |   3.84x |
| heavy_quoting_60k.csv          |   3.42x |
| many_empty_fields_60k.csv      |   3.36x |
| sample_100k.csv                |   3.17x |
| sensor_data_50krows_50cols.csv |   3.23x |
| tab_separated_60k.tsv          |   3.14x |
| utf8_multibyte_60k.csv         |   3.17x |
