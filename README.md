# ForenSys
### Forensic Medical Department Database Management System

![Spring Boot](https://img.shields.io/badge/Spring_Boot-6DB33F?style=for-the-badge&logo=springboot&logoColor=white)
![React](https://img.shields.io/badge/React-20232A?style=for-the-badge&logo=react&logoColor=61DAFB)
![PostgreSQL](https://img.shields.io/badge/PostgreSQL-316192?style=for-the-badge&logo=postgresql&logoColor=white)
![PL/pgSQL](https://img.shields.io/badge/PL%2FpgSQL-4169E1?style=for-the-badge&logo=postgresql&logoColor=white)


A secure, centralized Database Management System tailored for Forensic Medical Departments to digitize patient demographics, clinical forensic records (MLEF), autopsy investigations, and evidence chain-of-custody tracking.

---

## 📌 Project Overview

Forensic medical departments serve as a critical bridge between medicine and the justice system by handling sensitive clinical forensic evaluations and postmortem investigations. To function effectively, these departments require precise, highly secure, and instant data management.

Currently, many institutions rely heavily on manual paper-based record keeping, which introduces severe vulnerabilities:
- **Paper Record Vulnerabilities:** Physical documents are prone to physical degradation, misplacement, and damage.
- **Search Inefficiencies:** Manually retrieving patient demographics or historical medico-legal examination form (MLEF) records is time-consuming.
- **Confidentiality Risks:** Maintaining strict privacy is difficult when physical files can be easily misplaced or accessed without authorization.
- **Labor-Intensive Report Generation:** Compiling comprehensive autopsy or court reports by hand is prone to human error and delays.
- **Evidence Tracking Challenges:** Ensuring a strict chain of custody for physical evidence and media assets without automation is highly error-prone.

**ForenSys** addresses these challenges by delivering a complete, secure, and normalized database system to streamline medico-legal processes and administrative workflows.

---

## 🎯 Objectives

### General Objective
To design and develop a complete, secure Database System for a Forensic Medical Department to digitize and streamline medico-legal processes into a centralized, reliable platform.

### Specific Objectives
- **Digitize Records:** Automate the handling of patient demographics and clinical forensic (MLEF) records.
- **Autopsy & Death Tracking:** Streamline and track autopsy workflows and postmortem investigations.
- **Secure Evidence Repository:** Establish a secure repository for physical evidence and media assets with full chain-of-custody tracking.
- **Database Integrity:** Enforce high normalization levels and clear functional dependencies within the PostgreSQL schema.
- **Automated Reporting:** Enable instant querying of historical case files and rapid generation of standardized medical and court reports.

---

## 🏗 System Architecture & Technology Stack

The project utilizes a monolithic system architecture engineered for reliability, data isolation, and strict regulatory compliance:

| Layer | Technology | Description |
| :--- | :--- | :--- |
| **Frontend** | ![React](https://img.shields.io/badge/React-20232A?style=flat-square&logo=react&logoColor=61DAFB) | Responsive web UI for administrative workflows, patient management, and report generation |
| **Backend** | ![Spring Boot](https://img.shields.io/badge/Spring_Boot-6DB33F?style=flat-square&logo=springboot&logoColor=white) | Robust RESTful API service managing business logic, authorization, and data auditing |
| **Database** | ![PostgreSQL](https://img.shields.io/badge/PostgreSQL-316192?style=flat-square&logo=postgresql&logoColor=white) ![SQL](https://img.shields.io/badge/SQL-003B5C?style=flat-square&logo=database&logoColor=white) ![PL/pgSQL](https://img.shields.io/badge/PL%2FpgSQL-4169E1?style=flat-square&logo=postgresql&logoColor=white) | Highly normalized relational database with strict constraints, procedures, and functional dependencies |
| **Security** | RBAC & Cryptography | Role-Based Access Control and cryptographic measures to protect sensitive legal evidence |

---

## 👥 Team Members

| Reg No. | Name | Email |
| :--- | :--- | :--- |
| **E/22/182** | Dinith Kariyawasam | [e22182@eng.pdn.ac.lk](mailto:e22182@eng.pdn.ac.lk) |
| **E/22/291** | Rameesha Prathapasinghe | [e22291@eng.pdn.ac.lk](mailto:e22291@eng.pdn.ac.lk) |
| **E/22/421** | Tharindu Weerasinghe | [e22421@eng.pdn.ac.lk](mailto:e22421@eng.pdn.ac.lk) |
| **E/22/449** | Gayumi Wimalaweera | [e22449@eng.pdn.ac.lk](mailto:e22449@eng.pdn.ac.lk) |

---

**KernelX E22** <br>
**Department of Computer Engineering**  
**Faculty of Engineering, University of Peradeniya**
