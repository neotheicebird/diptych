## MODIFIED Requirements
### Requirement: Horizontal Split Canvas
The application interface SHALL be divided horizontally into two equal-sized panes (Top and Bottom), each capable of rendering an independent camera feed.

#### Scenario: Independent Feeds
- **GIVEN** the application is in Dual-Stream mode
- **WHEN** the layout renders
- **THEN** the Top Pane displays the `texture_top` feed and the Bottom Pane displays the `texture_bottom` feed.
