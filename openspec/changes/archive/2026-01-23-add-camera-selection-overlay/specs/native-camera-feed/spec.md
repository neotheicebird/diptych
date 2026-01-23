## ADDED Requirements
### Requirement: Camera Device Selection
The system SHALL allow selecting specific physical camera inputs for each logical feed (Top/Bottom).

#### Scenario: Listing Devices
- **WHEN** the system initializes
- **THEN** it provides a list of available physical devices (e.g., "Wide", "Ultra Wide", "Telephoto") valid for the current session type.

#### Scenario: Switching Device
- **GIVEN** a feed is active (e.g., Top)
- **WHEN** a request to set the device to "Telephoto" is received
- **THEN** the system reconfigures the capture input to use the "Telephoto" lens for that feed without stopping the session if possible.
