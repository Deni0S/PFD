# Primary Flight Display
[![Status](https://img.shields.io/badge/status-deprecated-red)](#)
[![Purpose](https://img.shields.io/badge/purpose-educational%20%2F%20history-blue)](#)
[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](./LICENSE)
[![Year](https://img.shields.io/badge/year-2019-lightgrey)](#)

> **This project is no longer maintained.**
> It is kept as an educational subproject for reference and historical purposes.
> The code may be incomplete, outdated, or contain educational simplifications.

The application simulates an **aircraft command attitude indicator** installed on board an aircraft. The module displays the spatial position of the aircraft in real time along with all related sensors — just like in a real aircraft cockpit. The instrument mimics the real logic of a flight and navigation system.

![Demo](Screens/Process.gif)

### Instrument Elements

| Element | Purpose |
|---------|---------|
| **Aircraft symbol** | Fixed center reference |
| **Pitch scale** | Nose-up / nose-down attitude |
| **Roll index and scale** | Bank angle |
| **Horizon line** | Sky/ground divider |
| **Slip indicator** | Lateral slip |
| **Ground speed** | GS190 |
| **Radio altitude** | DH200 / 2000 |
| **Speed deviation and scale** | F — increase, S — decrease |
| **Glideslope deviation and scale** | Vertical navigation |
| **Autothrottle mode indicator** | IAS / G/S |
| **Pitch indication mode** | LOC / CMD |
| **Status indicator** | Command mode |
| **Localizer deviation** | Course to runway |

### Control Surfaces

<p align="center">
  <img src="Screens/Rotations.jpg" alt="Ailerons, rudder, elevator">
</p>

- **Roll** — aileron deflection.
- **Yaw** — rudder deflection.
- **Pitch** — elevator deflection.

All three axes affect the instrument readings in real time.