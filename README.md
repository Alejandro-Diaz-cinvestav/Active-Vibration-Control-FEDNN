# Active Vibration Control of a Flexible Structure using FEDNN and MRAC

This repository contains the numerical simulations and experimental implementation code for my Doctoral Thesis: *"Modelado y Control de Estructuras Flexibles"*.

The project focuses on the active vibration attenuation of a flexible cantilever beam (an underactuated distributed parameter system) using a Finite Element Differential Neural Network (FEDNN) combined with a Model Reference Adaptive Control (MRAC).

## 🚀 Key Features
- **System Identification:** FEM-based Neural Network (FEDNN) for high-fidelity spatio-temporal modeling.
- **Control Strategies (Simulation):** Velocity Feedback (VOF), Neuro-Sliding Mode Control (NSMC), and Adaptive Control (MRAC).
- **Experimental Setup:** Real-time closed-loop control using Vicon Nexus (MoCap), MATLAB, and magnetic actuators driven by Arduino/L293D.

## 📂 Repository Structure
- `/Simulation_Control`: MATLAB scripts for VOF, NSMC, and MRAC numerical validation.
- `/Experimental_Implementation`: Real-time MATLAB scripts that interface with Vicon Nexus and send serial commands to the actuation hardware.
- `/Hardware`: Arduino `.ino` files for H-bridge (L293D) modulation and exogenous perturbation generation.
- `/Data`: Sample experimental data (`.mat`) required to run the simulations.

## 💻 Prerequisites & Software
To run the codes in this repository, you will need:
- MATLAB R202X or newer (Required toolboxes: Control System, Deep Learning...)
- Arduino IDE
- Vicon Nexus 2.x (Only for the experimental real-time data acquisition)

## 🛠️ Hardware Setup
The physical implementation requires:
- 2x Arduino UNO/Mega boards (one for control, one for perturbation)
- L293D H-Bridge motor drivers
- Electromagnets 
- Non-ferromagnetic cantilever beam (Aluminum) with optical passive markers.

## 📜 Citation
If you find this code useful for your research, please consider citing my thesis:
```bibtex
agregar el bibtex cuando este disponible
