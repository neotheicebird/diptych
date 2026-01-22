## ADDED Requirements

### Requirement: Zone A Layout
Zone A SHALL be arranged horizontally with three sections: Left Control (Top Pane), Center (Status), and Right Control (Bottom Pane).

#### Scenario: Layout Rendering
- **WHEN** the application starts
- **THEN** Zone A displays the Left Selector, Status Label, and Right Selector in a horizontal row.

### Requirement: Camera Selector UI
The Left and Right controls SHALL display the currently selected focal length/type (e.g., "1x", "0.5x") and be labeled to indicate their target pane ("TOP", "BOT").

#### Scenario: Selector Display
- **GIVEN** the Top pane is using the Wide camera (1x)
- **WHEN** the UI renders
- **THEN** the Left Selector displays text like "TOP: 1x".

### Requirement: Camera Cycling
Tapping a selector SHALL cycle through the list of available physical cameras for that pane.

#### Scenario: User changes camera
- **GIVEN** the Top pane is on "1x" and the next available camera is "3x"
- **WHEN** the user taps the Left Selector
- **THEN** the selector text updates to "TOP: 3x" and the Top pane switches to the Telephoto feed.

### Requirement: Single-Camera Fallback
On devices with only one rear camera, the selectors SHALL indicate the single available lens and maintain a linked state if necessary.

#### Scenario: Single camera device
- **GIVEN** the device has only one "1x" camera
- **WHEN** the app initializes
- **THEN** both selectors display "1x" (or similar) and cannot be switched to a non-existent lens.

### Requirement: Native Interface
The Native Bridge SHALL expose methods to query available cameras and set the active camera for a specific view.

#### Scenario: Querying cameras
- **WHEN** `get_available_cameras()` is called
- **THEN** it returns an Array of Dictionaries containing camera IDs and labels.
