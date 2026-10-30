# 2.4 GHz Microstrip Patch Antenna Design

## Project Overview
This project presents the design, layout optimization, and electromagnetic full-wave simulation of a rectangular microstrip patch antenna optimized to operate at the 2.4 GHz ISM band. 

## Software Framework
* **GNU Octave** — Used for parametric script control, geometric dimensioning, and post-processing calculation.
* **openEMS** — An open-source Electromagnetic Field Solver utilizing the Finite-Difference Time-Domain (FDTD) method.

## Design Specifications
* **Target Resonant Frequency:** 2.4 GHz
* **Substrate Dielectric Permittivity ($\epsilon_r$):** 3.38 (e.g., Rogers RO4003C or similar)
* **Substrate Height / Thickness ($h$):** 1.524 mm
* **Feed Mechanism:** Inset Microstrip Corporate Feedline for 50 $\Omega$ impedance matching.

## Engineering Workflow
1. **Mathematical Estimation:** Analytical computation of theoretical patch width ($W$) and length ($L$) using transmission line models.
2. **CAD Modeling & FDTD Gridding:** Building the structure programmatically in Octave and setting up the non-uniform mesh grid.
3. **Excitation & Simulation:** Defining properties for conducting copper layers, ports, and boundaries before launching the full-wave simulation.
4. **Data Acquisition:** Extracting S-parameters ($S_{11}$ return loss), input impedance matrices, and far-field 2D/3D radiation fields.

## File Directory Directory Structure
* `microstrip_antenna_design.m` — Main functional simulation script.
* `2.4GHz_Microstrip_Patch_Antenna_Project_Documentation.pdf` — Comprehensive engineering report outlining calculations.
* `image_...` & `photo_...` files — Captured return loss data plots, impedance curves, and far-field radiation graphs.

