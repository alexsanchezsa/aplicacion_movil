import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class MainButton extends StatelessWidget {
  final IconData? icon;
  final String text;
  final VoidCallback onTap;
  final String? svgAsset;
  final Color? iconColor;
  final Color? textColor;

  const MainButton({
    super.key,
    this.icon,
    this.svgAsset,
    required this.text,
    required this.onTap,
    this.iconColor,
    this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        splashColor: Colors.blue.withOpacity(0.1),
        highlightColor: Colors.transparent,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            children: [
              if (svgAsset != null)
                SvgPicture.asset(svgAsset!, height: 28, width: 28)
              else if (icon != null)
                Icon(
                  icon,
                  size: 28,
                  color: iconColor ?? const Color(0xFF1A73E8),
                ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  text,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color:
                        textColor ??
                        const Color(0xFF1A73E8), // ✅ usa el color que pases
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
