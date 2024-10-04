import 'package:flutter/material.dart';
import 'package:flutter_svg_image/flutter_svg.dart';

String bubbles = '''
  <svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" width="428" height="213" viewBox="0 0 428 213">
  <defs>
    <clipPath id="clip-path">
      <rect id="Rectangle_564" data-name="Rectangle 564" width="428" height="213" transform="translate(4032 2445)" fill="#05a6dd"/>
    </clipPath>
  </defs>
  <g id="Group_846" data-name="Group 846" transform="translate(-3478 -2445)">
    <rect id="Rectangle_563" data-name="Rectangle 563" width="428" height="213" transform="translate(3478 2445)" fill="#05a6dd"/>
    <g id="Mask_Group_8" data-name="Mask Group 8" transform="translate(-554)" clip-path="url(#clip-path)">
      <g id="Group_845" data-name="Group 845" transform="translate(4020 2421)">
        <circle id="Ellipse_146" data-name="Ellipse 146" cx="31" cy="31" r="31" transform="translate(403 70)" fill="#89dbf6" opacity="0.36"/>
        <circle id="Ellipse_147" data-name="Ellipse 147" cx="21" cy="21" r="21" transform="translate(298 44)" fill="#89dbf6" opacity="0.36"/>
        <circle id="Ellipse_152" data-name="Ellipse 152" cx="31" cy="31" r="31" transform="translate(331 82)" fill="#89dbf6" opacity="0.36"/>
        <circle id="Ellipse_148" data-name="Ellipse 148" cx="16" cy="16" r="16" transform="translate(345 17)" fill="#89dbf6" opacity="0.36"/>
        <circle id="Ellipse_151" data-name="Ellipse 151" cx="10.5" cy="10.5" r="10.5" transform="translate(297 110)" fill="#89dbf6" opacity="0.36"/>
        <circle id="Ellipse_153" data-name="Ellipse 153" cx="12.5" cy="12.5" r="12.5" transform="translate(286 12)" fill="#89dbf6" opacity="0.36"/>
        <circle id="Ellipse_149" data-name="Ellipse 149" cx="16" cy="16" r="16" transform="translate(387 37)" fill="#89dbf6" opacity="0.36"/>
      </g>
    </g>
  </g>
</svg>
'''
    .replaceAll('#05a6dd', "#ebfaf9")
    .replaceAll('#89dbf6', "#ffe6ff");

void main() {
  runApp(MaterialApp(
    home: Scaffold(
      body: Center(
        child: FlutterSvgImage.string(
          bubbles,
          fit: BoxFit.cover,
        ),
      ),
    ),
  ));
}
