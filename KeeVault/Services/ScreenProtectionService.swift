import UIKit

@MainActor
final class ScreenProtectionService {
    private weak var windowScene: UIWindowScene?
    private var shieldWindow: UIWindow?

    init(windowScene: UIWindowScene? = nil) {
        self.windowScene = windowScene
    }

    func updateScene(_ scene: UIWindowScene?) {
        windowScene = scene
    }

    func showShield() {
        guard let scene = windowScene ?? UIApplication.shared.connectedScenes
            .first(where: { $0.activationState == .foregroundActive || $0.activationState == .foregroundInactive }) as? UIWindowScene else {
            return
        }

        if shieldWindow == nil {
            let window = UIWindow(windowScene: scene)
            window.windowLevel = .alert + 1
            window.isUserInteractionEnabled = false
            window.backgroundColor = .clear
            window.rootViewController = ScreenProtectionViewController()
            shieldWindow = window
        }

        shieldWindow?.isHidden = false
    }

    func hideShield() {
        shieldWindow?.isHidden = true
    }
}

private final class ScreenProtectionViewController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()

        let blur = UIVisualEffectView(effect: UIBlurEffect(style: .systemChromeMaterial))
        blur.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(blur)

        let icon = UIImageView(image: UIImage(systemName: "lock.shield.fill"))
        icon.tintColor = .label
        icon.contentMode = .scaleAspectFit
        icon.translatesAutoresizingMaskIntoConstraints = false
        blur.contentView.addSubview(icon)

        let title = UILabel()
        title.text = "KeeVault Locked"
        title.font = .preferredFont(forTextStyle: .headline)
        title.textColor = .label
        title.translatesAutoresizingMaskIntoConstraints = false
        blur.contentView.addSubview(title)

        NSLayoutConstraint.activate([
            blur.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            blur.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            blur.topAnchor.constraint(equalTo: view.topAnchor),
            blur.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            icon.centerXAnchor.constraint(equalTo: blur.contentView.centerXAnchor),
            icon.centerYAnchor.constraint(equalTo: blur.contentView.centerYAnchor, constant: -16),
            icon.widthAnchor.constraint(equalToConstant: 48),
            icon.heightAnchor.constraint(equalToConstant: 48),

            title.topAnchor.constraint(equalTo: icon.bottomAnchor, constant: 12),
            title.centerXAnchor.constraint(equalTo: blur.contentView.centerXAnchor),
        ])
    }
}
