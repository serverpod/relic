64 connections, 5s per run, latency in ms with latency correction.

| target | workload | load | offered rps | rps | p50 | p99 | p99.9 |
|---|---|---|---|---|---|---|---|
| io | plaintext | 50% | 5570 | 5569 | 0.56 | 1.55 | 5.63 |
| io | plaintext | 75% | 8355 | 8353 | 0.85 | 2.96 | 7.37 |
| io | plaintext | 100% | 11140 | 11134 | 6.16 | 18.19 | 20.07 |
| io | headers | 50% | 3308 | 3308 | 0.59 | 1.40 | 2.65 |
| io | headers | 75% | 4962 | 4961 | 0.86 | 2.33 | 5.82 |
| io | headers | 100% | 6616 | 6612 | 9.46 | 18.96 | 21.04 |
| native4 | plaintext | 50% | 48890 | 48868 | 0.64 | 1.85 | 3.86 |
| native4 | plaintext | 75% | 73335 | 73314 | 0.90 | 4.56 | 10.98 |
| native4 | plaintext | 100% | 97780 | 97726 | 1.03 | 13.70 | 17.81 |
| native4 | headers | 50% | 27955 | 27944 | 0.72 | 1.70 | 3.82 |
| native4 | headers | 75% | 41933 | 41922 | 1.05 | 4.11 | 7.41 |
| native4 | headers | 100% | 55910 | 55756 | 10.16 | 22.98 | 25.93 |
