# Modelo de colas de la entrada (M/M/c)

Parámetros: 330 asistentes, 2 entradas, llegada en 15 min (lambda = 22.0 personas/min), 2000 simulaciones por escenario.

- El tiempo manual (23.8 s) se calibró para reproducir la espera de 25 min que reporta la Dirección de Graduados.
- El tiempo con QR (8 s) es un **supuesto** hasta medirlo en el simulacro.

| Escenario | Atención por persona (s) | Puntos | rho | Espera promedio (min) | Espera p95 (min) | Espera máx (min) | Ingreso completo (min) | % en menos de 5 min |
|---|---|---|---|---|---|---|---|---|
| Manual (lista impresa) | 23.8 | 2 | 4.37 | 25.1 | 48.4 | 61.9 | 65.8 | 10.6 % |
| Apolo QR | 8.0 | 2 | 1.47 | 3.6 | 7.3 | 12.6 | 22.2 | 71.4 % |
| Apolo QR, 2 tablets por entrada | 8.0 | 4 | 0.73 | 0.1 | 0.3 | 1.1 | 15.3 | 100.0 % |

Para que la espera promedio sea menor a 5 min con 2 puntos, cada lectura debe tardar como máximo **9.1 s** por persona.
