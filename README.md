# ar-camera-objective-c

AR-powered camera application written in **Objective-C** that demonstrates how to place and manage photo thumbnails in 3-D space using **ARKit**.

---

## Features

• Live camera feed rendered with `ARSCNView`  
• Reticle indicating the centre of the scene where new photos will be anchored (in develop)  
• Persisted photo thumbnails in AR

---

## Project Structure

```
ar-camera-objective-c/
├── ar-camera-objective-c/          # iOS target source
│   ├── Models/                     # Plain Objective-C model objects
│   ├── ViewModels/                 # Presentation logic (MVVM)
│   ├── Views/                      # SceneKit & UIKit views
│   ├── Services/                   # Business logic & system wrappers
│   └── Utils/                      # Helpers / extensions
├── ar-camera-objective-cTests/     # Unit tests
└── ar-camera-objective-cUITests/   # UI tests
```

## Key Classes

| Layer        | Class/Protocol                    | Purpose |
|--------------|-----------------------------------|---------|
| View         | `ARCanvasView`                    | Manages SceneKit nodes: canvas, reticle, thumbnails |
| ViewModel    | `ARCameraViewModel`               | Exposes reactive properties/actions for the view |
| Services     | `ARService`, `ARSpaceService`     | High-level AR session orchestration & node math |
| Services     | `MotionService`, `LocationService`| Device motion & GPS abstraction |
| Services     | `PhotoService`                    | Persisting photo metadata and thumbnails |

---

## Getting Started

### Prerequisites

• iOS 15.6+ **device** (ARKit does **not** run in the simulator)  

### Installation

```
# 1. Clone the repository
$ git clone https://github.com/sergoutback/ar-camera-objective-c.git
$ cd ar-camera-objective-c

# 2. Open the Xcode project
$ open ar-camera-objective-c.xcodeproj

# 3. Select the `ar-camera-objective-c` scheme and run on a connected iPhone

### How to play

First, make sure to detect at least two surfaces. Then you can take a few photos and view the thumbnails directly in AR. After that, you can export the PNG and JSON files via the standard iPhone share sheet, or reset the session. Feedback is welcome and appreciated!
```

> NOTE: Grant camera & motion permissions on first launch.


## Architecture

The app follows (at list tried to follow) a lightweight **MVVM** architecture:

1. **View (UIKit/SceneKit)** – renders UI and forwards user input.  
2. **ViewModel** – pure Objective-C objects exposing data via properties & delegates for easy unit testing.  
3. **Services** – wrap frameworks (ARKit, CoreMotion, CoreLocation) to provide a clean, mockable interface.

Dependencies flow downwards only – views know about their view models, which know about services. Models are value objects free of business logic.

---

## License

Distributed under the MIT License. See `LICENSE` for more information.
