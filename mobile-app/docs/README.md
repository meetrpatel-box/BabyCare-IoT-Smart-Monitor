# BabyTrack Flutter Documentation

This directory contains comprehensive documentation for the BabyTrack Flutter application.

## 📚 Documentation Structure

### 01-overview/
Product vision, strategy, and design guidelines
- `1.1-product-vision.md` - Product vision and goals
- `1.2-retention-strategy.md` - User retention and engagement strategy
- `1.3-design-guidelines.md` - UI/UX design principles and guidelines

### 02-architecture/
System architecture and data flow
- `2.1-architecture-overview.md` - High-level system architecture
- `2.2-data-architecture.md` - Data models and database schema
- `COMPLETE_DATA_FLOW.md` - End-to-end data flow documentation
- `DATA_IO_AT_EACH_LAYER.md` - Data input/output at each architectural layer
- `DEVICE_TO_APP_DATA_FLOW.md` - ESP32 device to mobile app data flow
- `SERVICE_ARCHITECTURE.md` - Microservices and backend architecture

### 03-specifications/
Technical specifications and requirements
- `device/` - Hardware device specifications
  - `3.1.1-device-lifecycle.md` - Device lifecycle management
  - `HARDWARE_SENSORS_SPECIFICATION.md` - Sensor hardware specifications
  - `WIFI_PROVISIONING_FLOW.md` - WiFi setup and provisioning flow

### 04-backend/
Cloud Functions, API reference, and backend architecture
- `4.1-cloud-functions-overview.md` - Cloud Functions setup, deployment, and architecture
- `4.2-api-reference.md` - Complete API reference for all callable functions
- `4.3-firestore-schema.md` - Firestore schema for cry detection & ML pipeline
- `4.4-security-model.md` - Firestore security rules and access control

### 05-operations/
Testing, monitoring, and operational procedures
- `5.1-testing-strategy.md` - Overall testing strategy
- `5.2-error-monitoring.md` - Error tracking and monitoring setup
- `5.3-testing-architecture.md` - Testing infrastructure architecture

### 06-project/
Project management and status tracking
- `6.1-development-roadmap.md` - Feature development roadmap
- `6.2-implementation-status.md` - Current implementation status
- `6.3-gap-analysis.md` - Feature gap analysis
- `6.4-world-class-gap-analysis.md` - Comparison with world-class apps
- `6.5-sensor-hardware-architecture.md` - Hardware architecture
- `6.6-infant-knowledge-guidance.md` - AI-powered guidance system
- `CURRENT_STATUS.md` - Current project status

### 07-research/
Research and competitive analysis
- `current-app-value-proposition.md` - App value proposition and differentiation

### 08-implementation/
Low-level design documents for features

- **Core Features:**
  - `DIAPER_TRACKING_LLD.md` - Diaper tracking system
  - `FEEDING_TRACKING_LLD.md` - Feeding tracking system
  - `GROWTH_TRACKING_LLD.md` - Growth monitoring system
  - `MEDICATION_TRACKING_LLD.md` - Medication management
  - `MILESTONE_SYSTEM_LLD.md` - Developmental milestone tracking
  - `PHOTO_MEMORY_SYSTEM_LLD.md` - Photo and memory management
  - `SLEEP_TRACKING_LLD.md` - Sleep tracking system
  - `VACCINE_TRACKING_LLD.md` - Vaccination schedule tracking
  - `VITAL_SIGNS_MONITORING_LLD.md` - Real-time vital signs monitoring

- **Cry Detection & ML Pipeline:**
  - `CRY_DETECTION_LLD.md` - Progressive multi-modal cry detection system
  - `COLIC_PATTERN_DETECTION_LLD.md` - Colic analysis using Wessel's criteria
  - `MODEL_SYSTEM_LLD.md` - ML model loading, versioning, and A/B testing
  - `ADMIN_PANEL_LLD.md` - Admin dashboard for model management
  - `CONSENT_AND_PRIVACY_LLD.md` - 3-tier data consent and GDPR compliance

- **Hardware Integration:**
  - `MMWAVE_SENSOR_INTEGRATION.md` - mmWave sensor integration
  - `VITAL_SIGNS_ARCHITECTURE_SUMMARY.md` - Vital signs architecture

- **Photo/Video:**
  - `DEVICE_SIDE_PHOTO_VIDEO_ARCHITECTURE.md` - Device-side photo/video capture
  - `PHOTO_VIDEO_SERVICE_FLOW.md` - Photo/video service workflows

- **AI & Analytics:**
  - `EDGE_VS_CLOUD_AI_ANALYSIS.md` - Edge vs Cloud AI analysis
  - `HYBRID_AI_IMPLEMENTATION_PLAN.md` - AI implementation strategy
  - `SLEEP_ANALYSIS_ALGORITHMS.md` - Sleep analysis algorithms
  - `SLEEP_ANALYSIS_IMPLEMENTATION.md` - Sleep analysis implementation
  - `SLEEP_ANALYTICS_DETAILED_EXAMPLE.md` - Sleep analytics examples

- **WiFi Provisioning:**
  - `PHASE1_WIFI_PROVISIONING_FLUTTER.md` - WiFi provisioning Phase 1 implementation
  - `WIFI_PROVISIONING_QUICK_WINS.md` - Quick improvements for WiFi setup
  - `WIFI_PROVISIONING_UX_PROPOSAL.md` - WiFi provisioning UX design

- **System Design:**
  - `LOW_LEVEL_DESIGN.md` - General low-level design patterns
  - `AGENT_IMPLEMENTATION_PLAN.md` - AI agent implementation plan

### 09-testing/
Test documentation and guides
- `ESP32_SIMULATOR_TESTING_GUIDE.md` - ESP32 device simulator testing
- `FAMILY_INVITATION_TESTING.md` - Family invitation feature testing
- `INTEGRATION_TESTING_GUIDE.md` - End-to-end integration testing
- `CLOUD_FUNCTIONS_TESTING.md` - Cloud Functions testing guide (Jest, mocking patterns)

### 10-build-deploy/
Build and deployment documentation
- `BUILD_GUIDE.md` - Complete build guide for Android and iOS
- `BUILD_README.md` - Quick build reference

## 🚀 Quick Start

1. **New to the project?** Start with [`01-overview/1.1-product-vision.md`](01-overview/1.1-product-vision.md)
2. **Want to understand architecture?** Read [`02-architecture/2.1-architecture-overview.md`](02-architecture/2.1-architecture-overview.md)
3. **Working on Cloud Functions?** See [`04-backend/4.1-cloud-functions-overview.md`](04-backend/4.1-cloud-functions-overview.md)
4. **Need API docs?** Check [`04-backend/4.2-api-reference.md`](04-backend/4.2-api-reference.md)
5. **Implementing a feature?** Check [`08-implementation/`](08-implementation/) for LLD docs
6. **Working on cry detection?** Start with [`08-implementation/CRY_DETECTION_LLD.md`](08-implementation/CRY_DETECTION_LLD.md)
7. **Building for production?** See [`10-build-deploy/BUILD_GUIDE.md`](10-build-deploy/BUILD_GUIDE.md)
8. **Running tests?** Visit [`09-testing/`](09-testing/) for test guides

## 📝 Documentation Standards

### File Naming
- Use descriptive kebab-case names: `feature-name-description.md`
- Prefix with section number when in numbered folders: `1.1-product-vision.md`
- Use all caps for major documents: `README.md`, `ARCHITECTURE.md`

### Document Structure
All documents should include:
```markdown
# Title

**Document ID**: DOC-X.X or LLD-FEATURE-001
**Version**: 1.0.0
**Status**: 🟢 Complete
**Last Updated**: YYYY-MM-DD

---

## Executive Summary
Brief description of the document

## Details
Detailed content

## Related Documents
Links to related documentation
```

### Status Icons

| Status | Icon | Description |
|--------|------|-------------|
| Complete | 🟢 | Production-ready, tested |
| Partial | 🟡 | Started, needs work |
| Not Started | 🔴 | Planned, no code yet |
| N/A | ⚪ | Not applicable yet |

### Updating Documentation
- Keep docs in sync with code changes
- Update status and implementation docs regularly
- Archive outdated documents instead of deleting
- Link related documents together

## 🔗 External Resources

- **Flutter**: https://flutter.dev/docs
- **Firebase**: https://firebase.google.com/docs
- **ESP32**: https://docs.espressif.com/

## 📧 Documentation Team

For questions about documentation:
- Create an issue in the repository
- Tag documentation in PR descriptions
- Update this README when adding new sections

---

**Last Updated:** February 19, 2026
**Documentation Version:** 3.0
