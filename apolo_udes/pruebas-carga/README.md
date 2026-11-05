# Pruebas de carga y modelo de colas

Evidencia del **objetivo 4**: que el sistema aguanta una ceremonia completa y que
reduce la espera en la entrada. No necesitan `npm install`: solo usan Node.

> Todo corre contra el **emulador** de Firestore con datos inventados. Nunca se
> escribe en la base de datos real.

## 1. Pruebas de carga (`carga.js`)

Desde `C:\Apolo-Udes\apolo_udes`:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File pruebas-carga\ejecutar.ps1
```

| Escenario | Qué comprueba |
|---|---|
| A. Flujo normal | Dos tablets (Entrada 1 y 2) leen 110, 500 y 1000 asistentes, una persona tras otra |
| B. Doble escaneo | 200 códigos leídos en las dos tablets **al mismo tiempo**: cada uno debe entrar una sola vez |
| C. Estrés | 1000 lecturas con 50 a la vez, como si hubiera 50 tablets |

Cada lectura hace lo mismo que la app: crea `usos/{codigo}` (el servidor decide
si el código ya se usó) y guarda el registro en `validaciones`. El resultado
queda en `resultados\carga-<fecha>.md` (tabla lista para el libro) y `.json`.
Si hay una entrada doble o algún error, el script termina en rojo.

La latencia que mide es la del emulador en el computador, **sin internet**. La
demora real (tablet + wifi de la universidad) se mide en el simulacro.

## 2. Modelo de colas (`colas.js`)

```powershell
cd C:\Apolo-Udes\apolo_udes\pruebas-carga
node colas.js
```

Modelo M/M/c con los datos de la Dirección de Graduados: 330 asistentes,
2 entradas, llegada en 15 minutos y 25 minutos de espera actual. En la
apertura llega más gente de la que se alcanza a atender (rho > 1), así que
además de las fórmulas de Erlang C se simula la llegada 2000 veces.

- El tiempo de atención **manual** no se supone: se calibra para que la
  simulación dé los 25 minutos que se observan hoy.
- El tiempo con **QR** (8 s) es un supuesto hasta medirlo. Cuando lo midas en
  el simulacro, vuelve a correrlo con el dato real:

```powershell
node colas.js --qr-seg 6.5
```

Otros parámetros: `--asistentes`, `--entradas`, `--ventana-min`,
`--espera-observada-min`, `--repeticiones`. El informe queda en
`resultados\colas.md`.
