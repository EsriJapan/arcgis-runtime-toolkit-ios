// Copyright 2019 Esri.

// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
// http://www.apache.org/licenses/LICENSE-2.0

// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import UIKit
import ARKit
import ArcGISToolkit
import ArcGIS

class ARExample: UIViewController {
    
    typealias sceneInitFunction = () -> AGSScene
    
    /// The scene creation functions plus labels.  The functions create a new scene and perform any necessary `ArcGISARView` initialization.  This allows for changing the scene and AR "mode" (table top or full-scale).
    private var sceneInfo: [(sceneFunction: sceneInitFunction, label: String)] = []
    
    /// The current scene info.
    private var currentSceneInfo: (sceneFunction: sceneInitFunction, label: String)?
    
    /// The `ArcGISARView` that displays the camera feed and handles ARKit functionality.
    let arView = ArcGISARView(renderVideoFeed: true, tryUsingARKit: true)
    
    /// Denotes whether we've performed a hit test yet.
    var didHitTest: Bool = false
        private let statusViewController: ARStatusViewController? = {
        let storyBoard = UIStoryboard(name: "ARStatusViewController", bundle: nil)
        let vc = storyBoard.instantiateInitialViewController() as? ARStatusViewController
        vc?.modalPresentationStyle = .popover
        return vc
    }()
    /// Used when calculating framerate.
    private var lastUpdateTime: TimeInterval = 0

    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Set ourself as delegate so we can get ARSCNViewDelegate method calls.
        arView.arSCNViewDelegate = self
        
        // Set ourself as touch delegate so we can get touch events.
        arView.sceneView.touchDelegate = self
        
        // Add arView to the view and setup the constraints.
        view.addSubview(arView)
        arView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            arView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            arView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            arView.topAnchor.constraint(equalTo: view.topAnchor),
            arView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
            ])
        
        
        // Create a toolbar and add it to the arView.
        let toolbar = UIToolbar(frame: .zero)
        arView.addSubview(toolbar)
        toolbar.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            toolbar.leadingAnchor.constraint(equalTo: arView.sceneView.leadingAnchor),
            toolbar.trailingAnchor.constraint(equalTo: arView.sceneView.trailingAnchor),
            toolbar.bottomAnchor.constraint(equalTo: arView.sceneView.attributionTopAnchor)
            ])
        
        // Add a toolbar button to change the current scene.
        let sceneItem = UIBarButtonItem(title: "Change Scene", style: .plain, target: self, action: #selector(changeScene(_:)))
        toolbar.setItems([UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil),
                          sceneItem,
                          UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)], animated: false)
        
        // Set up the `sceneInfo` array with our scene init functions and labels.
        sceneInfo.append(contentsOf: [(sceneFunction: streetsScene, label: "Streets"),
                                      (sceneFunction: everestScene, label: "Everest"),
                                      (sceneFunction: broncosStadiumScene, label: "Broncos Stadium"),
                                      (sceneFunction: emptyScene, label: "Empty")])
        
        // Use the first sceneInfo to create and set the scene.
        currentSceneInfo = sceneInfo.first
        arView.sceneView.scene = currentSceneInfo?.sceneFunction()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        arView.startTracking { (error) in
            if let error = error {
                print("Error starting ArcGISARView tracking: \(error)")
            }
        }
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        arView.stopTracking()
    }
    
    /// Changes the scene to a newly selected scene.
    ///
    /// - Parameter sender: The bar button item tapped on.
    @objc func changeScene(_ sender: UIBarButtonItem){
        guard let label = currentSceneInfo?.label,
            // Get the index of the scene currently shown in the sceneView.
            let selectedIndex = sceneInfo.firstIndex(where: { $0.label == label }) else {
                return
        }
        
        // Create the array of labels for the options table view controller.
        let sceneLabels = sceneInfo.map { $0.label }
        
        // A view controller allowing the user to select the scene to show.
        // Note: the `OptionsTableViewController` is copied from the "ArcGIS Runtime SDK for iOS Samples" code, found here:  https://github.com/Esri/arcgis-runtime-samples-ios
        let controller = OptionsTableViewController(labels: sceneLabels, selectedIndex: selectedIndex) { [weak self] (newIndex) in
            if let self = self {
                // Dismiss the popover.
                self.dismiss(animated: true, completion: nil)
                
                // Set currentSceneInfo to the selected scene.
                self.currentSceneInfo = self.sceneInfo[newIndex]
                
                // Stop tracking, update the scene with the selected Scene and start tracking again.
                self.arView.stopTracking()
                self.arView.sceneView.scene = self.sceneInfo[newIndex].sceneFunction()
                self.arView.startTracking()
            }
        }
        
        // Configure the options controller as a popover.
        controller.modalPresentationStyle = .popover
        controller.presentationController?.delegate = self
        controller.preferredContentSize = CGSize(width: 300, height: 300)
        controller.popoverPresentationController?.barButtonItem = sender
        controller.popoverPresentationController?.passthroughViews?.append(arView)
        
        // Show the popover.
        present(controller, animated: true)
    }
        @objc func showStatus(){
        guard let statusVC = statusViewController else { return }
        statusVC.popoverPresentationController?.barButtonItem = navigationItem.rightBarButtonItem
        statusVC.preferredContentSize = {
            let height: CGFloat = CGFloat(statusVC.tableView.numberOfRows(inSection: 0)) * statusVC.tableView.rowHeight
            return CGSize(width: 375, height: height)
        }()

        navigationController?.present(statusVC, animated: true, completion: nil)
    }

    // MARK: Scene Init Functions
    
    /// Creates a scene based on the Streets base map.
    ///
    /// - Returns: The new scene.
    private func streetsScene() -> AGSScene {
        
        // Create scene with the streets basemap.
        let scene = AGSScene(basemapType: .streets)
        addElevationSource(toScene: scene)
        
        // Set the location data source so we use our GPS location as the originCamera.
        arView.locationDataSource = AGSCLLocationDataSource()
        return scene
    }
    
    /// Creates a scene based on the Mount Everest web scene.
    ///
    /// - Returns: The new scene.
    private func everestScene() -> AGSScene {
        // Create scene using the Everest web scene.
        let portal = AGSPortal.arcGISOnline(withLoginRequired: false)
        let portalItem = AGSPortalItem(portal: portal, itemID: "27f76008eeb04765b8a94d998aaa46c7")
        let scene = AGSScene(item: portalItem)
        
        // Set camera to Everest summit.
        arView.originCamera = AGSCamera(latitude: 27.988153, longitude: 86.925174, altitude: 8868.069399, heading: 159.56, pitch: 0.00, roll: 0.00)
        arView.translationFactor = 1000
        
        // Clear the location data source, as we're setting the originCamera directly.
        arView.locationDataSource = nil
        return scene
    }
    
    /// Creates a scene based on the Broncos stadium web scene.
    ///
    /// - Returns: The new scene.
    private func broncosStadiumScene() -> AGSScene {
        // Create scene using WebScene of the Broncos stadium
        let portal = AGSPortal.arcGISOnline(withLoginRequired: false)
        let portalItem = AGSPortalItem(portal: portal, itemID: "72460f2c5b4048339433afedcb2369e1")
        let scene = AGSScene(item: portalItem)
        
        scene.load { [weak self] (error) in
            if let error = error {
                print("Error loading scene: \(error)")
                return
            }
            // Set the originCamera to be the initial viewpoint of the web scene.
            self?.arView.originCamera = scene.initialViewpoint.camera
            self?.arView.translationFactor = 1000
        }
        
        // Turn off background grid.
        scene.baseSurface?.backgroundGrid.isVisible = false
        
        // Clear the location data source, as we're setting the originCamera directly.
        arView.locationDataSource = nil
        return scene
    }
    
    /// Creates an empty scene with an elevation source.
    ///
    /// - Returns: The new scene.
    private func emptyScene() -> AGSScene {
        let scene = AGSScene()
        addElevationSource(toScene: scene)
        
        // Set the location data source so we use our GPS location as the originCamera.
        arView.locationDataSource = AGSCLLocationDataSource()
        return scene
    }
    
    /// Adds an elevation source to the given `scene`.
    ///
    /// - Parameter scene: The scene to add the elevation source to.
    private func addElevationSource(toScene scene: AGSScene) {
        let elevationSource = AGSArcGISTiledElevationSource(url: URL(string: "https://elevation3d.arcgis.com/arcgis/rest/services/WorldElevation3D/Terrain3D/ImageServer")!)
        let surface = AGSSurface()
        surface.elevationSources = [elevationSource]
        surface.name = "baseSurface"
        surface.isEnabled = true
        surface.backgroundGrid.isVisible = false
        scene.baseSurface = surface
    }
}

extension ARExample: ARSCNViewDelegate {
    
    func renderer(_ renderer: SCNSceneRenderer, didAdd node: SCNNode, for anchor: ARAnchor) {
        // Place content only for anchors found by plane detection.
        guard let planeAnchor = anchor as? ARPlaneAnchor else { return }
        
        // Create a custom object to visualize the plane geometry and extent.
        let plane = Plane(anchor: planeAnchor, in: arView.arSCNView)
        
        // Add the visualization to the ARKit-managed node so that it tracks
        // changes in the plane anchor as plane estimation continues.
        node.addChildNode(plane)
    }
    
    func renderer(_ renderer: SCNSceneRenderer, didUpdate node: SCNNode, for anchor: ARAnchor) {
        // Update only anchors and nodes set up by `renderer(_:didAdd:for:)`.
        guard let planeAnchor = anchor as? ARPlaneAnchor,
            let plane = node.childNodes.first as? Plane
            else { return }
        
        // Update extent visualization to the anchor's new bounding rectangle.
        if let extentGeometry = plane.extentNode.geometry as? SCNPlane {
            extentGeometry.width = CGFloat(planeAnchor.extent.x)
            extentGeometry.height = CGFloat(planeAnchor.extent.z)
            plane.extentNode.simdPosition = planeAnchor.center
        }
    }
    
    func session(_ session: ARSession, didFailWithError error: Error) {
        guard error is ARError else { return }
        
        let errorWithInfo = error as NSError
        let messages = [
            errorWithInfo.localizedDescription,
            errorWithInfo.localizedFailureReason,
            errorWithInfo.localizedRecoverySuggestion
        ]
        
        // Remove optional error messages.
        let errorMessage = messages.compactMap({ $0 }).joined(separator: "\n")
        
        // Set the error message on the status vc.
        statusViewController?.errorMessage = errorMessage
        
        DispatchQueue.main.async { [weak self] in
            // Present an alert describing the error.
            let alertController = UIAlertController(title: "Could not start tracking.", message: errorMessage, preferredStyle: .alert)
            let restartAction = UIAlertAction(title: "Restart Tracking", style: .default) { _ in
                self?.arView.startTracking()
            }
            alertController.addAction(restartAction)
            
            self?.present(alertController, animated: true)
        }
    }
    func session(_ session: ARSession, cameraDidChangeTrackingState camera: ARCamera) {
        // Set the tracking state on the status vc.
        statusViewController?.trackingState = camera.trackingState
    }
    
    func renderer(_ renderer: SCNSceneRenderer, willRenderScene scene: SCNScene, atTime time: TimeInterval) {
        // Calculate frame rate and set on the statuc vc.
        let frametime = time - lastUpdateTime
        statusViewController?.frameRate = Int((1.0 / frametime).rounded())
        lastUpdateTime = time
    }
}

extension ARExample: AGSGeoViewTouchDelegate {
    public func geoView(_ geoView: AGSGeoView, didTapAtScreenPoint screenPoint: CGPoint, mapPoint: AGSPoint) {
        guard !didHitTest else { return }
        
        if arView.setInitialTransformation(screenPoint: screenPoint) {
            didHitTest = true
        }
        
        //        guard let point = arView.arScreenToLocation(screenPoint: screenPoint) else { return }
        //
        //        let newpoint = AGSPointMake3D(point.x, point.y, 0, 0, point.spatialReference)
        //        let sym = AGSModelSceneSymbol(name:"Bristol", extension: "dae", scale: 50.0)
        //        sym.load { (error) in
        //            print("error loading sym: \(String(describing: error))")
        //        }
        //        let graphic = AGSGraphic(geometry: newpoint, symbol: sym, attributes: nil)
        //        graphicsOverlay.graphics.add(graphic)
        //        print("mapPoint: \(mapPoint)")
        //        print("point: \(point)")
        
        //        guard let initialCamera = initialCamera else { print("No initial camera"); return }
        //        var initialTransformation = arView.initialTransformation
        //        initialTransformation = initialTransformation.subtractTransformation(initialCamera.transformationMatrix)
        //        let _ = arView.setInitialTransformation(initialTransformation: initialTransformation)
    }
}

extension ARExample: UIAdaptivePresentationControllerDelegate {
    func adaptivePresentationStyle(for controller: UIPresentationController, traitCollection: UITraitCollection) -> UIModalPresentationStyle {
        // show presented controller as popovers even on small displays
        return .none
    }
}
