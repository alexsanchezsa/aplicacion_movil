import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class MainButton extends StatelessWidget {
  final IconData? icon;
  final String text;
  final VoidCallback onTap;
  final String? svgAsset;
  final Color? iconColor;
  final Color? textColor;
  final String? imagePath;

  const MainButton({
    super.key,
    this.icon,
    this.svgAsset,
    this.imagePath,
    required this.text,
    required this.onTap,
    this.iconColor,
    this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(40),
          splashColor: Colors.white.withOpacity(0.2),
          highlightColor: Colors.white.withOpacity(0.1),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [
                  Color(0xFF1E88E5), // Azul más claro
                  Color(0xFF1565C0), // Azul más oscuro
                ],
              ),
              borderRadius: BorderRadius.circular(40),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF1565C0).withOpacity(0.4),
                  blurRadius: 12,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Row(
              children: [
                // Círculo blanco con icono
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Center(
                    child: _buildIcon(),
                  ),
                ),
                const SizedBox(width: 16),
                // Texto
                Expanded(
                  child: Text(
                    text.toUpperCase(),
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: textColor ?? Colors.white,
                      letterSpacing: 0.5,
                      shadows: [
                        Shadow(
                          color: Colors.black.withOpacity(0.2),
                          offset: const Offset(0, 1),
                          blurRadius: 2,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildIcon() {
    if (imagePath != null) {
      return ClipOval(
        child: Image.asset(
          imagePath!,
          width: 45,
          height: 45,
          fit: BoxFit.contain,
        ),
      );
    } else if (svgAsset != null) {
      return SvgPicture.asset(
        svgAsset!,
        height: 35,
        width: 35,
        colorFilter: iconColor != null
            ? ColorFilter.mode(iconColor!, BlendMode.srcIn)
            : null,
      );
    } else if (icon != null) {
      return Icon(
        icon,
        size: 35,
        color: iconColor ?? const Color(0xFF1565C0),
      );
    }
    return const SizedBox();
  }
}
