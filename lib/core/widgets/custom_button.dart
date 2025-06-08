/*
 * Guardian - Women's Safety App
 * © 2025 All Rights Reserved - Kunal Singh
 * Contact: kunalsingh2514@gmail.com
 */

import 'package:flutter/material.dart';
import 'package:guardian/core/constants/app_colors.dart';

enum ButtonType { primary, secondary, outline, text }

class CustomButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final ButtonType type;
  final bool isLoading;
  final bool isFullWidth;
  final IconData? icon;
  final double height;
  final double? width;
  final double borderRadius;
  final EdgeInsets padding;

  const CustomButton({
    super.key,
    required this.text,
    required this.onPressed,
    this.type = ButtonType.primary,
    this.isLoading = false,
    this.isFullWidth = true,
    this.icon,
    this.height = 50,
    this.width,
    this.borderRadius = 8,
    this.padding = const EdgeInsets.symmetric(horizontal: 16),
  });

  @override
  Widget build(BuildContext context) {
    switch (type) {
      case ButtonType.primary:
        return _buildPrimaryButton();
      case ButtonType.secondary:
        return _buildSecondaryButton();
      case ButtonType.outline:
        return _buildOutlineButton();
      case ButtonType.text:
        return _buildTextButton();
    }
  }

  Widget _buildPrimaryButton() {
    return SizedBox(
      width: isFullWidth ? double.infinity : width,
      height: height,
      child: ElevatedButton(
        onPressed: isLoading || onPressed == null ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(borderRadius),
          ),
          padding: padding,
        ),
        child: _buildButtonContent(Colors.white),
      ),
    );
  }

  Widget _buildSecondaryButton() {
    return SizedBox(
      width: isFullWidth ? double.infinity : width,
      height: height,
      child: ElevatedButton(
        onPressed: isLoading || onPressed == null ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.secondary,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(borderRadius),
          ),
          padding: padding,
        ),
        child: _buildButtonContent(Colors.white),
      ),
    );
  }

  Widget _buildOutlineButton() {
    return SizedBox(
      width: isFullWidth ? double.infinity : width,
      height: height,
      child: OutlinedButton(
        onPressed: isLoading || onPressed == null ? null : onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primary,
          side: const BorderSide(color: AppColors.primary),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(borderRadius),
          ),
          padding: padding,
        ),
        child: _buildButtonContent(AppColors.primary),
      ),
    );
  }

  Widget _buildTextButton() {
    return SizedBox(
      width: isFullWidth ? double.infinity : width,
      height: height,
      child: TextButton(
        onPressed: isLoading || onPressed == null ? null : onPressed,
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primary,
          padding: padding,
        ),
        child: _buildButtonContent(AppColors.primary),
      ),
    );
  }

  Widget _buildButtonContent(Color color) {
    if (isLoading) {
      return SizedBox(
        height: 24,
        width: 24,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          valueColor: AlwaysStoppedAnimation<Color>(color),
        ),
      );
    }

    if (icon != null) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 8),
          Text(text),
        ],
      );
    }

    return Text(text);
  }
}
