import UIKit
import SceneKit

// MARK: - Constants

private let kEarthRadius: Float   = 1.0
private let kCameraZ: Float       = 3.6
private let kAutoRotate: Float    = 0.0035   // rad/frame at 30 fps
private let kBubbleW: CGFloat     = 124
private let kBubbleH: CGFloat     = 46
private let kPointerH: CGFloat    = 8
private let kBubbleTotalH: CGFloat = kBubbleH + kPointerH
private let kMaxBubbles           = 6
private let kVisibilityThreshold: Float = 0.08
private let kHysteresis           = 4   // frames before state change
private let kInteractionPause: TimeInterval = 3.0

// MARK: - RdioGlobeView

final class RdioGlobeView: UIView, UIGestureRecognizerDelegate {

    // MARK: - Data

    struct GlobePin {
        let country: ExploreCountry
        let localPos: SIMD3<Float>
    }

    // MARK: - Properties

    private let sceneView  = SCNView()
    private let overlay    = UIView()
    private var scene      = SCNScene()
    private var earthParent = SCNNode()
    private var cameraNode  = SCNNode()

    private var pins:           [GlobePin]             = []
    private var bubbles:        [String: RdioGlobeBubble] = [:]
    private var bubbleShown:    [String: Bool]          = [:]
    private var hysteresis:     [String: Int]           = [:]

    private var yAngle: Float           = 0
    private var xAngle: Float           = 0
    private var spinVelocityY: Float    = 0
    private var spinVelocityX: Float    = 0
    private var pauseUntil: Date?        = nil
    private var isDragging: Bool        = false
    private var lastPanX: CGFloat       = 0
    private var lastPanY: CGFloat       = 0
    private var lastInteractionTime: Date? = nil
    private weak var globePanGesture: UIPanGestureRecognizer?

    private var displayLink: CADisplayLink?
    private var tickCount = 0

    var onSelect: ((ExploreCountry) -> Void)?

    // MARK: - Init / deinit

    override init(frame: CGRect) {
        super.init(frame: frame)
        build()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        build()
    }

    deinit {
        displayLink?.invalidate()
    }

    override func didMoveToSuperview() {
        super.didMoveToSuperview()
        guard let globePanGesture,
              let scrollView = superview as? UIScrollView else { return }
        scrollView.panGestureRecognizer.require(toFail: globePanGesture)
    }

    // MARK: - Public API

    func configure(with countries: [ExploreCountry]) {
        pins = countries.compactMap { c -> GlobePin? in
            guard let (lat, lon) = Self.coords[c.code] else { return nil }
            return GlobePin(country: c, localPos: spherePos(lat: lat, lon: lon))
        }
        // Initial rotation: face SE Asia (lon ≈ 108°)
        xAngle = 0
        yAngle = -Float(108.0 * .pi / 180.0)
        earthParent.eulerAngles = SCNVector3(xAngle, yAngle, 0)
        buildBubbles()
    }

    // MARK: - Setup

    private func build() {
        backgroundColor = .clear
        clipsToBounds = false
        setupScene()
        setupOverlay()
        setupGestures()
        startDisplayLink()
    }

    private func setupScene() {
        sceneView.scene = scene
        sceneView.backgroundColor = .clear
        sceneView.allowsCameraControl = false
        sceneView.isUserInteractionEnabled = false
        sceneView.antialiasingMode = .multisampling2X
        sceneView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(sceneView)
        NSLayoutConstraint.activate([
            sceneView.topAnchor.constraint(equalTo: topAnchor),
            sceneView.leadingAnchor.constraint(equalTo: leadingAnchor),
            sceneView.trailingAnchor.constraint(equalTo: trailingAnchor),
            sceneView.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])

        // Camera
        cameraNode.camera = SCNCamera()
        cameraNode.camera?.zNear = 0.1
        cameraNode.camera?.zFar = 100
        cameraNode.camera?.fieldOfView = 42
        cameraNode.position = SCNVector3(0, 0, kCameraZ)
        scene.rootNode.addChildNode(cameraNode)

        // Ambient + directional lights
        let ambient = SCNNode()
        ambient.light = SCNLight()
        ambient.light?.type = .ambient
        ambient.light?.color = UIColor(white: 0.35, alpha: 1)
        scene.rootNode.addChildNode(ambient)

        let sun = SCNNode()
        sun.light = SCNLight()
        sun.light?.type = .directional
        sun.light?.color = UIColor(white: 0.9, alpha: 1)
        sun.eulerAngles = SCNVector3(-0.4, 0.6, 0)
        scene.rootNode.addChildNode(sun)

        // Earth parent (rotates on Y)
        scene.rootNode.addChildNode(earthParent)

        // Base sphere (dark ocean)
        let base = SCNSphere(radius: CGFloat(kEarthRadius * 0.994))
        base.segmentCount = 64
        let baseMat = SCNMaterial()
        baseMat.diffuse.contents = UIColor(red: 0.02, green: 0.05, blue: 0.13, alpha: 1)
        baseMat.emission.contents = UIColor(red: 0.01, green: 0.02, blue: 0.06, alpha: 1)
        baseMat.lightingModel = .phong
        baseMat.shininess = 0.6
        base.firstMaterial = baseMat
        earthParent.addChildNode(SCNNode(geometry: base))

        // Atmosphere glow ring (thin translucent sphere)
        let atmoGeom = SCNSphere(radius: CGFloat(kEarthRadius * 1.02))
        atmoGeom.segmentCount = 48
        let atmoMat = SCNMaterial()
        atmoMat.diffuse.contents = UIColor(red: 0.15, green: 0.35, blue: 0.65, alpha: 0.06)
        atmoMat.emission.contents = UIColor(red: 0.1, green: 0.25, blue: 0.6, alpha: 0.08)
        atmoMat.lightingModel = .constant
        atmoMat.isDoubleSided = true
        atmoMat.cullMode = .front
        atmoMat.blendMode = .add
        atmoMat.writesToDepthBuffer = false
        atmoGeom.firstMaterial = atmoMat
        earthParent.addChildNode(SCNNode(geometry: atmoGeom))

        generateDots()
    }

    private func setupOverlay() {
        overlay.backgroundColor = .clear
        overlay.isUserInteractionEnabled = false
        overlay.translatesAutoresizingMaskIntoConstraints = false
        addSubview(overlay)
        NSLayoutConstraint.activate([
            overlay.topAnchor.constraint(equalTo: topAnchor),
            overlay.leadingAnchor.constraint(equalTo: leadingAnchor),
            overlay.trailingAnchor.constraint(equalTo: trailingAnchor),
            overlay.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
    }

    private func setupGestures() {
        let pan = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
        pan.maximumNumberOfTouches = 1
        pan.cancelsTouchesInView = true
        pan.delegate = self
        addGestureRecognizer(pan)
        globePanGesture = pan

        let tap = UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))
        addGestureRecognizer(tap)
    }

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        false
    }

    private func startDisplayLink() {
        displayLink = CADisplayLink(target: self, selector: #selector(tick))
        displayLink?.preferredFrameRateRange = CAFrameRateRange(minimum: 20, maximum: 60, preferred: 30)
        displayLink?.add(to: .main, forMode: .common)
    }

    // MARK: - Dot generation

    private func generateDots() {
        let r = kEarthRadius
        let dotCount = 4200

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self else { return }
            guard let path = Bundle.main.path(forResource: "earth-dark", ofType: "jpg"),
                  let srcImage = UIImage(contentsOfFile: path),
                  let srcCG = srcImage.cgImage else { return }

            let imgW = srcCG.width
            let imgH = srcCG.height

            // Redraw into a guaranteed RGBA8 context to avoid byte-order surprises
            var pixels = [UInt8](repeating: 0, count: imgW * imgH * 4)
            let colorSpace = CGColorSpaceCreateDeviceRGB()
            let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue)
            guard let ctx = CGContext(
                data: &pixels,
                width: imgW, height: imgH,
                bitsPerComponent: 8, bytesPerRow: imgW * 4,
                space: colorSpace, bitmapInfo: bitmapInfo.rawValue
            ) else { return }
            ctx.draw(srcCG, in: CGRect(x: 0, y: 0, width: imgW, height: imgH))

            var landPositions: [SCNVector3] = []
            landPositions.reserveCapacity(dotCount * 4)

            let candidateCount = dotCount * 8
            let goldenAngle = Double.pi * (3.0 - sqrt(5.0))
            let radius = Double(r * 1.035)

            for i in 0..<candidateCount {
                let t = (Double(i) + 0.5) / Double(candidateCount)
                let y = 1.0 - (2.0 * t)
                let horizontal = sqrt(max(0.0, 1.0 - (y * y)))
                let theta = Double(i) * goldenAngle
                let x = cos(theta) * horizontal
                let z = sin(theta) * horizontal

                let lon = atan2(x, z)
                let lat = asin(y)
                let u = (lon + Double.pi) / (2.0 * Double.pi)
                let v = (Double.pi / 2.0 - lat) / Double.pi
                let px = min(imgW - 1, max(0, Int(u * Double(imgW))))
                let py = min(imgH - 1, max(0, Int(v * Double(imgH))))
                let idx = ((imgW * py) + px) * 4

                guard Self.isLandPixel(red: pixels[idx], green: pixels[idx + 1], blue: pixels[idx + 2], v: v) else { continue }
                landPositions.append(SCNVector3(Float(x * radius), Float(y * radius), Float(z * radius)))
            }

            guard !landPositions.isEmpty else { return }

            var positions: [SCNVector3] = []
            positions.reserveCapacity(min(dotCount, landPositions.count))
            let step = max(1, landPositions.count / dotCount)
            var cursor = 0
            while positions.count < dotCount && cursor < landPositions.count {
                positions.append(landPositions[cursor])
                cursor += step
            }

            guard !positions.isEmpty else { return }

            let source = SCNGeometrySource(vertices: positions)
            let indices = positions.indices.map(Int32.init)
            let indexData = indices.withUnsafeBufferPointer { Data(buffer: $0) }
            let element = SCNGeometryElement(
                data: indexData,
                primitiveType: .point,
                primitiveCount: positions.count,
                bytesPerIndex: MemoryLayout<Int32>.size
            )
            element.pointSize = 1.8
            element.minimumPointScreenSpaceRadius = 1.0
            element.maximumPointScreenSpaceRadius = 2.1

            let geom = SCNGeometry(sources: [source], elements: [element])
            let mat  = SCNMaterial()
            let dotColor = UIColor(white: 0.96, alpha: 0.92)
            mat.diffuse.contents  = dotColor
            mat.emission.contents = dotColor
            mat.lightingModel = .constant
            mat.isDoubleSided = false
            mat.blendMode = .alpha
            mat.readsFromDepthBuffer = true
            mat.writesToDepthBuffer = false
            geom.firstMaterial = mat

            DispatchQueue.main.async { [weak self] in
                let node = SCNNode(geometry: geom)
                node.renderingOrder = 20
                self?.earthParent.addChildNode(node)
            }
        }
    }

    // MARK: - Bubbles

    private func buildBubbles() {
        bubbles.values.forEach { $0.removeFromSuperview() }
        bubbles.removeAll(); bubbleShown.removeAll(); hysteresis.removeAll()

        for pin in pins {
            let b = RdioGlobeBubble()
            b.configure(pin.country)
            b.alpha = 0
            overlay.addSubview(b)
            bubbles[pin.country.code]    = b
            bubbleShown[pin.country.code] = false
            hysteresis[pin.country.code] = 0
        }
    }

    // MARK: - Display link tick

    @objc private func tick() {
        if !isDragging {
            let now = Date()
            let paused = pauseUntil.map { now < $0 } ?? false
            let hasY = abs(spinVelocityY) > 0.0003
            let hasX = abs(spinVelocityX) > 0.0003

            if paused {
                spinVelocityY = 0
                spinVelocityX = 0
            } else if hasY || hasX {
                yAngle       += spinVelocityY
                spinVelocityY *= 0.88
                spinVelocityX = 0
            } else if !paused {
                spinVelocityY = 0; spinVelocityX = 0
                yAngle += kAutoRotate
            }
            // within 3s of last interaction: stay still
        }
        earthParent.eulerAngles = SCNVector3(xAngle, yAngle, 0)

        tickCount += 1
        if tickCount % 2 == 0 { updateBubbles() }
    }

    // MARK: - Bubble update (anti-overlap greedy)

    private func updateBubbles() {
        guard !pins.isEmpty, bounds.width > 0, bounds.height > 0 else { return }

        // Project all visible pins, sort by depth (most central first)
        let candidates: [(GlobePin, CGPoint, Float)] = pins.compactMap { pin in
            let local = SCNVector3(pin.localPos.x, pin.localPos.y, pin.localPos.z)
            let world = earthParent.convertPosition(local, to: nil)
            guard world.z > kVisibilityThreshold else { return nil }
            let proj  = sceneView.projectPoint(world)
            let pt    = CGPoint(x: CGFloat(proj.x), y: CGFloat(proj.y))
            guard bounds.insetBy(dx: 20, dy: 20).contains(pt) else { return nil }
            return (pin, pt, world.z)
        }.sorted { $0.2 > $1.2 }

        // Greedy placement — cap at kMaxBubbles
        var placed: [CGRect] = []
        var wantShow: [String: (show: Bool, frame: CGRect)] = [:]

        for (pin, center, _) in candidates {
            guard placed.count < kMaxBubbles else { break }
            let ox = center.x - kBubbleW / 2
            let oy = center.y - kBubbleTotalH - 5
            let rect = CGRect(x: ox, y: oy, width: kBubbleW, height: kBubbleTotalH)

            let overlaps = placed.contains { $0.insetBy(dx: -12, dy: -8).intersects(rect) }
            guard !overlaps else { continue }

            placed.append(rect)
            wantShow[pin.country.code] = (true, rect)
        }

        // Apply with hysteresis
        for pin in pins {
            let code = pin.country.code
            let target = wantShow[code]?.show ?? false
            let current = bubbleShown[code] ?? false

            if target == current {
                hysteresis[code] = 0
            } else {
                let h = (hysteresis[code] ?? 0) + 1
                hysteresis[code] = h
                if h >= kHysteresis {
                    hysteresis[code] = 0
                    bubbleShown[code] = target
                    if target, let rect = wantShow[code]?.frame {
                        bubbles[code]?.frame = rect
                    }
                    animateBubble(bubbles[code], visible: target)
                }
            }

            // Keep updating position for already-visible bubbles
            if current, let rect = wantShow[code]?.frame {
                bubbles[code]?.frame = rect
            }
        }

        // Hide bubbles for off-screen pins (not even in candidates)
        let visibleCodes = Set(candidates.map { $0.0.country.code })
        for pin in pins where !visibleCodes.contains(pin.country.code) {
            let code = pin.country.code
            if bubbleShown[code] == true {
                bubbleShown[code] = false
                hysteresis[code]  = 0
                animateBubble(bubbles[code], visible: false)
            }
        }
    }

    private func animateBubble(_ b: RdioGlobeBubble?, visible: Bool) {
        guard let b else { return }
        if visible {
            b.transform = CGAffineTransform(scaleX: 0.80, y: 0.80)
            UIView.animate(withDuration: 0.28, delay: 0, usingSpringWithDamping: 0.7, initialSpringVelocity: 0.5) {
                b.alpha = 1
                b.transform = .identity
            }
        } else {
            UIView.animate(withDuration: 0.18) {
                b.alpha = 0
                b.transform = CGAffineTransform(scaleX: 0.85, y: 0.85)
            } completion: { _ in b.transform = .identity }
        }
    }

    // MARK: - Gestures

    @objc private func handlePan(_ gr: UIPanGestureRecognizer) {
        let loc = gr.location(in: self)
        switch gr.state {
        case .began:
            isDragging    = true
            lastPanX      = loc.x
            lastPanY      = loc.y
            pauseAutoRotate()
        case .changed:
            let dx = Float(loc.x - lastPanX) * 0.009
            lastPanX = loc.x
            lastPanY = loc.y
            yAngle       += dx
            pauseAutoRotate()
            earthParent.eulerAngles = SCNVector3(xAngle, yAngle, 0)
        case .ended, .cancelled, .failed:
            isDragging = false
            lastInteractionTime = Date()
            pauseAutoRotate()
        default:
            break
        }
    }

    private func pauseAutoRotate() {
        pauseUntil = Date().addingTimeInterval(kInteractionPause)
        spinVelocityY = 0
        spinVelocityX = 0
    }

    @objc private func handleTap(_ gr: UITapGestureRecognizer) {
        let pt = gr.location(in: self)
        for pin in pins {
            guard let b = bubbles[pin.country.code], b.alpha > 0.4 else { continue }
            if b.frame.insetBy(dx: -10, dy: -10).contains(pt) {
                UIView.animate(withDuration: 0.08, animations: { b.transform = CGAffineTransform(scaleX: 0.92, y: 0.92) }) { _ in
                    UIView.animate(withDuration: 0.12) { b.transform = .identity }
                }
                onSelect?(pin.country)
                return
            }
        }
    }

    // MARK: - Coordinate helpers

    private func spherePos(lat: Double, lon: Double) -> SIMD3<Float> {
        let φ = Float(lat * .pi / 180)
        let λ = Float(lon * .pi / 180)
        return SIMD3<Float>(
            cos(φ) * sin(λ),   // x: east
            sin(φ),             // y: north
            cos(φ) * cos(λ)    // z: toward camera at lon=0
        ) * kEarthRadius
    }

    private static func isLandPixel(red: UInt8, green: UInt8, blue: UInt8, v: Double) -> Bool {
        guard v > 0.055 && v < 0.945 else { return false }
        let r = CGFloat(red) / 255
        let g = CGFloat(green) / 255
        let b = CGFloat(blue) / 255
        let luminance = (0.2126 * r) + (0.7152 * g) + (0.0722 * b)
        let chroma = max(r, g, b) - min(r, g, b)
        return luminance < 0.035 && chroma < 0.02
    }

    // MARK: - Country coordinates (lat, lon)

    private static let coords: [String: (Double, Double)] = [
        "MY": ( 3.8,  108.9), "SG": ( 1.4,  103.8), "ID": (-2.5,  118.0),
        "BN": ( 4.5,  114.7), "TH": (15.0,  101.0), "PH": (12.9,  121.8),
        "VN": (16.2,  107.8), "JP": (36.2,  138.3), "KR": (36.0,  127.8),
        "CN": (35.9,  104.2), "IN": (20.6,   79.1), "HK": (22.3,  114.2),
        "TW": (23.7,  121.0), "US": (38.0,  -97.0), "GB": (52.4,   -1.9),
        "DE": (51.2,   10.5), "FR": (46.2,    2.2), "NL": (52.1,    5.3),
        "AU": (-25.3, 133.8), "CA": (56.1, -106.3), "BR": (-10.8, -53.0),
        "AR": (-38.4,  -63.6),"MX": (23.6, -102.5), "RU": (61.5,  105.3),
        "ZA": (-30.6,  22.9),
    ]
}

// MARK: - RdioGlobeBubble

final class RdioGlobeBubble: UIView {
    private let flagLabel  = UILabel()
    private let nameLabel  = UILabel()
    private let countLabel = UILabel()

    override init(frame: CGRect) { super.init(frame: frame); build() }
    required init?(coder: NSCoder) { fatalError() }

    func configure(_ country: ExploreCountry) {
        flagLabel.text  = flag(country.code)
        nameLabel.text  = country.name
        let n = country.stationcount
        countLabel.text = n >= 1_000 ? String(format: "%.0fk stations", Double(n) / 1_000) : "\(n) stations"
    }

    private func build() {
        backgroundColor = .clear

        // Card background
        let card = UIVisualEffectView(effect: UIBlurEffect(style: .systemUltraThinMaterialDark))
        card.layer.cornerRadius = 10
        card.layer.borderWidth  = 0.5
        card.layer.borderColor  = UIColor.white.withAlphaComponent(0.22).cgColor
        card.clipsToBounds = true
        card.translatesAutoresizingMaskIntoConstraints = false
        addSubview(card)

        // Labels
        flagLabel.font  = .systemFont(ofSize: 15)
        nameLabel.font  = .systemFont(ofSize: 11, weight: .semibold)
        nameLabel.textColor  = UIColor(white: 0.95, alpha: 1)
        nameLabel.numberOfLines = 1
        countLabel.font = .systemFont(ofSize: 9, weight: .medium)
        countLabel.textColor = UIColor(white: 0.6, alpha: 1)
        countLabel.numberOfLines = 1

        let textStack = UIStackView(arrangedSubviews: [nameLabel, countLabel])
        textStack.axis    = .vertical
        textStack.spacing = 1

        let row = UIStackView(arrangedSubviews: [flagLabel, textStack])
        row.axis      = .horizontal
        row.spacing   = 6
        row.alignment = .center
        row.translatesAutoresizingMaskIntoConstraints = false
        card.contentView.addSubview(row)

        // Pointer
        let pointer = RdioGlobePointer()
        pointer.translatesAutoresizingMaskIntoConstraints = false
        addSubview(pointer)

        NSLayoutConstraint.activate([
            card.topAnchor.constraint(equalTo: topAnchor),
            card.leadingAnchor.constraint(equalTo: leadingAnchor),
            card.trailingAnchor.constraint(equalTo: trailingAnchor),
            card.heightAnchor.constraint(equalToConstant: kBubbleH),
            row.leadingAnchor.constraint(equalTo: card.contentView.leadingAnchor, constant: 10),
            row.trailingAnchor.constraint(equalTo: card.contentView.trailingAnchor, constant: -8),
            row.centerYAnchor.constraint(equalTo: card.contentView.centerYAnchor),
            pointer.topAnchor.constraint(equalTo: card.bottomAnchor, constant: -1),
            pointer.centerXAnchor.constraint(equalTo: centerXAnchor),
            pointer.widthAnchor.constraint(equalToConstant: 12),
            pointer.heightAnchor.constraint(equalToConstant: kPointerH + 1)
        ])
    }

    private func flag(_ code: String) -> String {
        let base: UInt32 = 127397
        return String(code.uppercased().unicodeScalars.compactMap {
            UnicodeScalar($0.value + base)
        }.map { Character($0) })
    }
}

// MARK: - RdioGlobePointer (downward triangle)

private final class RdioGlobePointer: UIView {
    override init(frame: CGRect) { super.init(frame: frame); backgroundColor = .clear }
    required init?(coder: NSCoder) { fatalError() }

    override func draw(_ rect: CGRect) {
        let path = UIBezierPath()
        path.move(to: CGPoint(x: 0, y: 0))
        path.addLine(to: CGPoint(x: rect.width, y: 0))
        path.addLine(to: CGPoint(x: rect.midX, y: rect.height))
        path.close()
        // Match blur card — approximate dark fill
        UIColor(white: 0.12, alpha: 0.88).setFill()
        path.fill()
    }
}
