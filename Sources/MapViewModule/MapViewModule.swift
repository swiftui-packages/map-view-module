//
//  MapView.swift
//  MapViewTest
//
//  Created by Cem Yilmaz on 05.07.21.
//

import SwiftUI
import MapKit

#if canImport(MapKit) && canImport(UIKit)
public struct MapView: UIViewRepresentable {

    @Binding private var region: MKCoordinateRegion
    
    private var customMapOverlay: CustomMapOverlay?
    @State private var presentCustomMapOverlayHash: CustomMapOverlay?
    
    private var mapType: MKMapType
    
    private var showZoomScale: Bool
    private var zoomEnabled: Bool
    private var zoomRange: (minHeight: CLLocationDistance?, maxHeight: CLLocationDistance?)
    
    private var scrollEnabled: Bool
    private var scrollBoundaries: MKCoordinateRegion?
    
    private var rotationEnabled: Bool
    private var showCompassWhenRotated: Bool
    
    private var showUserLocation: Bool
    private var userTrackingMode: MKUserTrackingMode
    @Binding private var userLocation: CLLocationCoordinate2D?
    
    private var annotations: [MKPointAnnotation]
    
    private var overlays: [Overlay]
    
    private var monitoredRegions: [MonitoredRegion]
    private var onEnterMonitoredRegion: ((_ id: UUID) -> Void)?
    private var onLeaveMonitoredRegion: ((_ id: UUID) -> Void)?
    
    public init(
        region: Binding<MKCoordinateRegion> = .constant(MKCoordinateRegion()),
        customMapOverlay: CustomMapOverlay? = nil,
        mapType: MKMapType = MKMapType.standard,
        zoomEnabled: Bool = true,
        showZoomScale: Bool = false,
        zoomRange: (minHeight: CLLocationDistance?, maxHeight: CLLocationDistance?) = (nil, nil),
        scrollEnabled: Bool = true,
        scrollBoundaries: MKCoordinateRegion? = nil,
        rotationEnabled: Bool = true,
        showCompassWhenRotated: Bool = true,
        showUserLocation: Bool = true,
        userTrackingMode: MKUserTrackingMode = MKUserTrackingMode.none,
        userLocation: Binding<CLLocationCoordinate2D?> = .constant(nil),
        annotations: [MKPointAnnotation] = [],
        overlays: [Overlay] = [],
        monitoredRegions: [MonitoredRegion] = [],
        onEnterMonitoredRegion: ((_ id: UUID) -> Void)? = nil,
        onLeaveMonitoredRegion: ((_ id: UUID) -> Void)? = nil
    ) {
        self._region = region
        
        self.customMapOverlay = customMapOverlay
        
        self.mapType = mapType
        
        self.showZoomScale = showZoomScale
        self.zoomEnabled = zoomEnabled
        self.zoomRange = zoomRange
        
        self.scrollEnabled = scrollEnabled
        self.scrollBoundaries = scrollBoundaries
        
        self.rotationEnabled = rotationEnabled
        self.showCompassWhenRotated = showCompassWhenRotated
        
        self.showUserLocation = showUserLocation
        self.userTrackingMode = userTrackingMode
        self._userLocation = userLocation
        
        self.annotations = annotations
        
        self.overlays = overlays
        
        self.monitoredRegions = monitoredRegions
        
        // initialized function stays constant, maybe a hash of a function in update could check for a change of function
        self.onEnterMonitoredRegion = onEnterMonitoredRegion
        self.onLeaveMonitoredRegion = onLeaveMonitoredRegion
    }
    
    public func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.delegate = context.coordinator
        return mapView
    }
    
    public func updateUIView(_ mapView: MKMapView, context: Context) {
        
        if self.userTrackingMode == MKUserTrackingMode.none && (mapView.region.center.latitude != self.region.center.latitude || mapView.region.center.longitude != self.region.center.longitude) {
            mapView.region = self.region
        }
        
        if self.customMapOverlay != self.presentCustomMapOverlayHash {
            mapView.removeOverlays(mapView.overlays)
            if let customMapOverlay = self.customMapOverlay {
                let overlay = CustomMapOverlaySource(
                    parent: self,
                    mapName: customMapOverlay.mapName,
                    tileType: customMapOverlay.tileType
                )
                
                if let minZ = customMapOverlay.minimumZoomLevel {
                    overlay.minimumZ = minZ
                }
                
                if let maxZ = customMapOverlay.maximumZoomLevel {
                    overlay.maximumZ = maxZ
                }
                
                overlay.canReplaceMapContent = customMapOverlay.canReplaceMapContent
                
                mapView.addOverlay(overlay)
            }
            DispatchQueue.main.async {
                self.presentCustomMapOverlayHash = self.customMapOverlay
            }
        }
        
        if mapView.overlays.count != (self.overlays.count + (self.customMapOverlay == nil ? 0 : 1)) {
            context.coordinator.overlays = self.overlays
            mapView.overlays.forEach { overlay in
                if !(overlay is MKTileOverlay) {
                    mapView.removeOverlay(overlay)
                }
            }
            mapView.addOverlays(self.overlays.map { overlay in overlay.shape })
        }
        
        if mapView.mapType != self.mapType {
            mapView.mapType = self.mapType
        }
        
        mapView.showsScale = self.zoomEnabled ? self.showZoomScale : false
        
        if mapView.isZoomEnabled != self.zoomEnabled {
            mapView.isZoomEnabled = self.zoomEnabled
        }
        
        if mapView.cameraZoomRange.minCenterCoordinateDistance != self.zoomRange.minHeight ?? 0 ||
            mapView.cameraZoomRange.maxCenterCoordinateDistance != self.zoomRange.maxHeight ?? .infinity {
            mapView.cameraZoomRange = MKMapView.CameraZoomRange(
                minCenterCoordinateDistance: self.zoomRange.minHeight ?? 0,
                maxCenterCoordinateDistance: self.zoomRange.maxHeight ?? .infinity
            )
        }
        
        mapView.isScrollEnabled = self.userTrackingMode == MKUserTrackingMode.none ? self.scrollEnabled : false
        
        if let scrollBoundary = self.scrollBoundaries, (mapView.cameraBoundary?.region.center.latitude != scrollBoundary.center.latitude || mapView.cameraBoundary?.region.center.longitude != scrollBoundary.center.longitude || mapView.cameraBoundary?.region.span.latitudeDelta != scrollBoundary.span.latitudeDelta || mapView.cameraBoundary?.region.span.longitudeDelta != scrollBoundary.span.longitudeDelta) {
            mapView.cameraBoundary = MKMapView.CameraBoundary(coordinateRegion: scrollBoundary)
        } else if self.scrollBoundaries == nil && mapView.cameraBoundary != nil {
            mapView.cameraBoundary = nil
        }
        
        mapView.isRotateEnabled = self.userTrackingMode != .followWithHeading ? self.rotationEnabled : false
        mapView.showsCompass = self.userTrackingMode != .followWithHeading ? self.showCompassWhenRotated : false
        
        if mapView.showsUserLocation != self.showUserLocation {
            mapView.showsUserLocation = self.showUserLocation
        }
        
        if mapView.userTrackingMode != self.userTrackingMode {
            mapView.userTrackingMode = self.userTrackingMode
        }
        
        if mapView.annotations.filter({ annotation in !(annotation is MKUserLocation) }).count != self.annotations.count {
            mapView.removeAnnotations(mapView.annotations)
            mapView.addAnnotations(self.annotations)
        }
        
        // maybe introduce hash to detect element changes or introduce getter and setter for full array
        if self.monitoredRegions.count != context.coordinator.monitoredRegions.count {
            context.coordinator.monitoredRegions = self.monitoredRegions
        }
        
    }
    
    public func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }
    
    public class Coordinator: NSObject, MKMapViewDelegate {
            
        private var parent: MapView
        public var overlays: [Overlay] = []
        public var monitoredRegions: [MonitoredRegion] = []
        
        init(parent: MapView) {
            self.parent = parent
        }
        
        public func mapView(_ mapView: MKMapView, didUpdate userLocation: MKUserLocation) {
            if let userCLLocation = userLocation.location {
                for index in 0..<self.monitoredRegions.count {
                    let distance = self.monitoredRegions[index].center.distance(from: userCLLocation)
                    if self.monitoredRegions[index].isInside && distance > CLLocationDistance(self.monitoredRegions[index].radius) {
                        if let onLeaveMonitoredRegion = self.parent.onLeaveMonitoredRegion {
                            onLeaveMonitoredRegion(self.monitoredRegions[index].id)
                        }
                        self.monitoredRegions[index].isInside = false
                    }
                    if !self.monitoredRegions[index].isInside && distance < CLLocationDistance(self.monitoredRegions[index].radius) {
                        if let onEnterMonitoredRegion = self.parent.onEnterMonitoredRegion {
                            onEnterMonitoredRegion(self.monitoredRegions[index].id)
                        }
                        self.monitoredRegions[index].isInside = true
                    }
                }
            }
            DispatchQueue.main.async {
                self.parent.userLocation = userLocation.coordinate
            }
        }
        
        public func mapViewDidChangeVisibleRegion(_ mapView: MKMapView) {
            DispatchQueue.main.async {
                self.parent.region = mapView.region
            }
        }
        
        public func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            
            if let index = self.overlays.firstIndex(where: { overlay_ in overlay_.shape.hash == overlay.hash }) {
                
                let unwrappedOverlay = self.overlays[index]

                if let circleOverlay = unwrappedOverlay.shape as? MKCircle {

                    let renderer = MKCircleRenderer(circle: circleOverlay)
                    renderer.fillColor = unwrappedOverlay.fillColor
                    renderer.strokeColor = unwrappedOverlay.strokeColor
                    renderer.lineWidth = unwrappedOverlay.lineWidth
                    return renderer

                } else if let polygonOverlay = unwrappedOverlay.shape as? MKPolygon {

                    let renderer = MKPolygonRenderer(polygon: polygonOverlay)
                    renderer.fillColor = unwrappedOverlay.fillColor
                    renderer.strokeColor = unwrappedOverlay.strokeColor
                    renderer.lineWidth = unwrappedOverlay.lineWidth
                    return renderer

                } else if let multiPolygonOverlay = unwrappedOverlay.shape as? MKMultiPolygon {

                    let renderer = MKMultiPolygonRenderer(multiPolygon: multiPolygonOverlay)
                    renderer.fillColor = unwrappedOverlay.fillColor
                    renderer.strokeColor = unwrappedOverlay.strokeColor
                    renderer.lineWidth = unwrappedOverlay.lineWidth
                    return renderer

                } else if let polyLineOverlay = unwrappedOverlay.shape as? MKPolyline {

                    let renderer = MKPolylineRenderer(polyline: polyLineOverlay)
                    renderer.fillColor = unwrappedOverlay.fillColor
                    renderer.strokeColor = unwrappedOverlay.strokeColor
                    renderer.lineWidth = unwrappedOverlay.lineWidth
                    return renderer

                } else if let multiPolylineOverlay = unwrappedOverlay.shape as? MKMultiPolyline {

                    let renderer = MKMultiPolylineRenderer(multiPolyline: multiPolylineOverlay)
                    renderer.fillColor = unwrappedOverlay.fillColor
                    renderer.strokeColor = unwrappedOverlay.strokeColor
                    renderer.lineWidth = unwrappedOverlay.lineWidth
                    return renderer

                } else {

                    return MKOverlayRenderer()

                }

            } else if let tileOverlay = overlay as? MKTileOverlay {

                return MKTileOverlayRenderer(tileOverlay: tileOverlay)

            } else {
                
                return MKOverlayRenderer()

            }
            
        }
        
    }
    
    public struct CustomMapOverlay: Equatable, Hashable {
        let mapName: String
        let tileType: String
        var canReplaceMapContent: Bool
        var minimumZoomLevel: Int?
        var maximumZoomLevel: Int?
        public init(
            mapName: String,
            tileType: String,
            canReplaceMapContent: Bool = true, // false for transparent tiles
            minimumZoomLevel: Int? = nil,
            maximumZoomLevel: Int? = nil
        ) {
            self.mapName = mapName
            self.tileType = tileType
            self.canReplaceMapContent = canReplaceMapContent
            self.minimumZoomLevel = minimumZoomLevel
            self.maximumZoomLevel = maximumZoomLevel
        }
    }
    
    public class CustomMapOverlaySource: MKTileOverlay {
        
        // requires folder: tiles/{mapName}/z/y/y,{tileType}
        
        private var parent: MapView
        private let mapName: String
        private let tileType: String
        
        public init(parent: MapView, mapName: String, tileType: String) {
            self.parent = parent
            self.mapName = mapName
            self.tileType = tileType
            super.init(urlTemplate: "")
        }
        
        public override func url(forTilePath path: MKTileOverlayPath) -> URL {
            if let tileUrl = Bundle.main.url(
                forResource: "\(path.y)",
                withExtension: "\(self.tileType)",
                subdirectory: "tiles/\(self.mapName)/\(path.z)/\(path.x)",
                localization: nil
            ) {
                return tileUrl
            } else {
                return URL(string: "https://tile.openstreetmap.org/\(path.z)/\(path.x)/\(path.y).png")!
                // Bundle.main.url(forResource: "surrounding", withExtension: "png", subdirectory: "tiles")!
            }
        
        }
        
    }
    
    public struct Overlay {
        
        public static func == (lhs: MapView.Overlay, rhs: MapView.Overlay) -> Bool {
            // maybe to use in the future for comparison of full array
            lhs.shape.coordinate.latitude == rhs.shape.coordinate.latitude &&
            lhs.shape.coordinate.longitude == rhs.shape.coordinate.longitude &&
            lhs.fillColor == rhs.fillColor
        }
        
        var shape: MKOverlay
        var fillColor: UIColor?
        var strokeColor: UIColor?
        var lineWidth: CGFloat

        public init(
            shape: MKOverlay,
            fillColor: UIColor? = nil,
            strokeColor: UIColor? = nil,
            lineWidth: CGFloat = 0
        ) {
            self.shape = shape
            self.fillColor = fillColor
            self.strokeColor = strokeColor
            self.lineWidth = lineWidth
        }
    }
    
    public struct MonitoredRegion {
        public var isInside: Bool = false
        public let id: UUID
        public let center: CLLocation
        public let radius: Int
        public init(
            id: UUID,
            center: CLLocation,
            radius: Int
        ) {
            self.id = id
            self.center = center
            self.radius = radius
        }
    }
    
}

// MARK: End of implementation

// MARK: Demonstration

public struct MapViewDemo: View {

    @State private var locationManager: CLLocationManager
    
    @State private var mapRegion: MKCoordinateRegion = MKCoordinateRegion(
        center: CLLocationCoordinate2D(
            latitude: 49.293,
            longitude: 8.642557
        ),
        span: MKCoordinateSpan(
            latitudeDelta: 0.01,
            longitudeDelta: 0.01
        )
    )
    
    @State private var customMapOverlay: MapView.CustomMapOverlay?
    
    @State private var mapType: MKMapType = MKMapType.standard
    
    @State private var zoomEnabled: Bool = true
    @State private var showZoomScale: Bool = true
    @State private var useMinZoomBoundary: Bool = false
    @State private var minZoom: Double = 0
    @State private var useMaxZoomBoundary: Bool = false
    @State private var maxZoom: Double = 3000000
    
    @State private var scrollEnabled: Bool = true
    @State private var useScrollBoundaries: Bool = false
    @State private var scrollBoundaries: MKCoordinateRegion = MKCoordinateRegion()
    
    @State private var rotationEnabled: Bool = true
    @State private var showCompassWhenRotated: Bool = true
    
    @State private var showUserLocation: Bool = true
    @State private var userTrackingMode: MKUserTrackingMode = MKUserTrackingMode.none
    @State private var userLocation: CLLocationCoordinate2D?
    
    @State private var showAnnotations: Bool = true
    @State private var annotations: [MKPointAnnotation] = []
    
    @State private var showOverlays: Bool = true
    @State private var overlays: [MapView.Overlay] = []
    
    @State private var showMapCenter: Bool = false
    
    public init() {
        self.locationManager = CLLocationManager()
        self.locationManager.requestWhenInUseAuthorization()
    }
    
    public var body: some View {

        NavigationView {
            
            List {

                Section(header: Text("Scroll")) {
                    Toggle("Scroll enabled", isOn: self.$scrollEnabled)
                    Toggle("Use scroll boundaries", isOn: self.$useScrollBoundaries)
                        .onChange(of: self.useScrollBoundaries) { newValue in
                            if newValue {
                                self.scrollBoundaries = MKCoordinateRegion(center: self.mapRegion.center, span: MKCoordinateSpan())
                            }
                        }
                    if self.useScrollBoundaries {
                        VStack(alignment: .leading) {
                            Text(String(format: "Vertical distance to center: %.2f m", self.scrollBoundaries.span.latitudeDelta * 10609))
                            Slider(value: self.$scrollBoundaries.span.latitudeDelta, in: 0...(300/10609))
                        }
                        VStack(alignment: .leading) {
                            Text(String(format: "Horizontal distance to center: %.2f m", self.self.scrollBoundaries.span.longitudeDelta * 10609))
                            Slider(value: self.$scrollBoundaries.span.longitudeDelta, in: 0...(300/10609))
                        }
                    }
                }
                
                Section(header: Text("Zoom")) {
                    Toggle("Zoom enabled", isOn: self.$zoomEnabled)
                    Toggle("Show zoom scale", isOn: self.$showZoomScale)
                    Toggle("Use minimum zoom boundary", isOn: self.$useMinZoomBoundary)
                    if self.useMinZoomBoundary {
                        VStack(alignment: .leading) {
                            Text(String(format: "Minimum Height: %.2f m", self.minZoom))
                            Slider(value: self.$minZoom, in: 0...(self.useMaxZoomBoundary ? self.maxZoom : 3000000), step: 10)
                        }
                    }
                    Toggle("Use maximum zoom boundary", isOn: self.$useMaxZoomBoundary)
                    if self.useMaxZoomBoundary {
                        VStack(alignment: .leading) {
                            Text(String(format: "Maximum Height: %.2f m", self.maxZoom))
                            Slider(value: self.$maxZoom, in: (self.useMinZoomBoundary ? self.minZoom : 0)...3000000, step: 10)
                        }
                    }
                }
                
                Section(header: Text("Rotation")) {
                    Toggle("Rotation enabled", isOn: self.$rotationEnabled)
                    Toggle("Show compass when rotated", isOn: self.$showCompassWhenRotated)
                }
                
                Section {
                    Toggle("Show map Center", isOn: self.$showMapCenter)
                }
                
                Section(header: Text("User Location")) {
                    Toggle("Show User Location", isOn: self.$showUserLocation)
                    Picker("Follow Mode", selection: self.$userTrackingMode) {
                        Text("Nicht folgen").tag(MKUserTrackingMode.none)
                        Text("Folgen").tag(MKUserTrackingMode.follow)
                        Text("Richtung folgen").tag(MKUserTrackingMode.followWithHeading)
                    }.pickerStyle(MenuPickerStyle())
                    
                }
                
                Section(header: Text("Annotations")) {
                    Toggle("Show Annotations", isOn: self.$showAnnotations)
                    Button("Add Annotation") {
                        let annotation = MKPointAnnotation()
                        annotation.coordinate = self.mapRegion.center
                        annotation.title = "Title"
                        annotation.subtitle = "Subtitle"
                        self.annotations.append(annotation)
                    }

                    Button("Delete all") { self.annotations = [] }.foregroundColor(.red)
                }
                
                Section(header: Text("Overlays")) {
                    Toggle("Show Overlays", isOn: self.$showOverlays)
                    Button("Add circle") {
                        self.overlays.append(MapView.Overlay(
                            shape: MKCircle(
                                center: self.mapRegion.center,
                                radius: 20
                            ),
                            strokeColor: UIColor.systemBlue,
                            lineWidth: 10
                        ))
                    }
                    
                    Button("Delete all") { self.overlays = [] }.foregroundColor(.red)
                }
                
                Section(header: Text("Custom Map Overlay")) {
                    Button("Keine") { self.customMapOverlay = nil }
                    Button("OSM Online") {
                        self.customMapOverlay = MapView.CustomMapOverlay(
                            mapName: "https://tile.openstreetmap.org/",
                            tileType: "png",
                            canReplaceMapContent: true
                        )
                    }
                }
                
            }.listStyle(GroupedListStyle())
            .navigationBarTitle("Map Configuration", displayMode: NavigationBarItem.TitleDisplayMode.inline)
            
            ZStack {
                
                MapView(
                    region: self.$mapRegion,
                    customMapOverlay: self.customMapOverlay,
                    mapType: self.mapType,
                    zoomEnabled: self.zoomEnabled,
                    showZoomScale: self.showZoomScale,
                    zoomRange: (minHeight: self.useMinZoomBoundary ? self.minZoom : 0, maxHeight: self.useMaxZoomBoundary ? self.maxZoom : .infinity),
                    scrollEnabled: self.scrollEnabled,
                    scrollBoundaries: self.useScrollBoundaries ? self.scrollBoundaries : nil,
                    rotationEnabled: self.rotationEnabled,
                    showCompassWhenRotated: self.showCompassWhenRotated,
                    showUserLocation: self.showUserLocation,
                    userTrackingMode: self.userTrackingMode,
                    userLocation: self.$userLocation,
                    annotations: self.showAnnotations ? self.annotations : [],
                    overlays: self.showOverlays ? self.overlays : []
                )
                
                VStack {
                    
                    Spacer()
                    
                    HStack {
                        if let userLocation = self.userLocation, self.showUserLocation {
                            VStack(alignment: .leading) {
                                Button("Center user location") {
                                    self.mapRegion.center = userLocation
                                }
                                Text("User Location").bold()
                                Text("\(userLocation.latitude)")
                                Text("\(userLocation.longitude)")
                            }
                        }
                        
                        Spacer()
                        
                        VStack(alignment: .leading) {
                            Text("Map Center").bold()
                            Text("\(self.mapRegion.center.latitude)")
                            Text("\(self.mapRegion.center.longitude)")
                        }
                    }
                    
                    Picker("", selection: self.$mapType) {
                        Text("Standard").tag(MKMapType.standard)
                        Text("Muted Standard").tag(MKMapType.mutedStandard)
                        Text("Satellite").tag(MKMapType.satellite)
                        Text("Satellite Flyover").tag(MKMapType.satelliteFlyover)
                        Text("Hybrid").tag(MKMapType.hybrid)
                        Text("Hybrid Flyover").tag(MKMapType.hybridFlyover)
                    }.pickerStyle(SegmentedPickerStyle())
                    
                    if self.showMapCenter {
                        Circle().frame(width: 8, height: 8).foregroundColor(.red)
                    }
                    
                }.padding()
                
            }.navigationBarTitle("SwiftUI MapView", displayMode: NavigationBarItem.TitleDisplayMode.inline)
            .ignoresSafeArea(edges: .bottom)
            
        }

    }

}


public struct MapView_Previews: PreviewProvider {

    public static var previews: some View {

        MapViewDemo()

    }

}
#endif
