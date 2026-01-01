#!/usr/bin/env python3
from PIL import Image, ImageDraw, ImageFont
import math

# Create a 1024x1024 image
size = 1024
image = Image.new('RGB', (size, size))
draw = ImageDraw.Draw(image)

# Create gradient background (red-orange theme)
for y in range(size):
    # Calculate color for this row
    ratio = y / size
    r = int(255 * (1.0 - ratio * 0.2))
    g = int((76 + ratio * 100))
    b = int((76 + ratio * 50))
    draw.line([(0, y), (size, y)], fill=(r, g, b))

# Draw white circle for clock face
center = size // 2
clock_radius = 380
draw.ellipse(
    [center - clock_radius, center - clock_radius,
     center + clock_radius, center + clock_radius],
    fill='white'
)

# Draw clock hour markers
marker_color = (255, 102, 77)  # Red-orange
for i in range(12):
    angle = math.radians(i * 30 - 90)
    outer_radius = clock_radius - 30
    inner_radius = clock_radius - 80

    x1 = center + outer_radius * math.cos(angle)
    y1 = center + outer_radius * math.sin(angle)
    x2 = center + inner_radius * math.cos(angle)
    y2 = center + inner_radius * math.sin(angle)

    draw.line([(x1, y1), (x2, y2)], fill=marker_color, width=20)

# Draw clock hands
# Hour hand (pointing to 10 o'clock)
hour_angle = math.radians(10 * 30 - 90)
hour_length = 180
hour_x = center + hour_length * math.cos(hour_angle)
hour_y = center + hour_length * math.sin(hour_angle)
draw.line([(center, center), (hour_x, hour_y)], fill=(51, 51, 51), width=30)

# Minute hand (pointing to 2)
minute_angle = math.radians(10 - 90)
minute_length = 260
minute_x = center + minute_length * math.cos(minute_angle)
minute_y = center + minute_length * math.sin(minute_angle)
draw.line([(center, center), (minute_x, minute_y)], fill=(77, 77, 77), width=24)

# Draw center circle
draw.ellipse(
    [center - 40, center - 40, center + 40, center + 40],
    fill=marker_color
)

# Try to add "AT" text
try:
    # Try to use a system font
    font_size = 180
    try:
        font = ImageFont.truetype("/System/Library/Fonts/SFCompact.ttf", font_size)
    except:
        try:
            font = ImageFont.truetype("/System/Library/Fonts/Helvetica.ttc", font_size)
        except:
            font = ImageFont.load_default()

    # Draw "AT" text at bottom
    text = "AT"
    # Get text bounding box
    bbox = draw.textbbox((0, 0), text, font=font)
    text_width = bbox[2] - bbox[0]
    text_height = bbox[3] - bbox[1]

    text_x = (size - text_width) // 2
    text_y = size - 200

    # Draw shadow
    shadow_offset = 8
    draw.text((text_x + shadow_offset, text_y + shadow_offset), text,
              fill=(0, 0, 0, 128), font=font)

    # Draw main text
    draw.text((text_x, text_y), text, fill='white', font=font)

except Exception as e:
    print(f"Could not add text: {e}")

# Save the image
output_path = '/Users/jamilkabir/Desktop/code/apple/iphone/ADHDTimerApp/ADHDTimerApp/Assets.xcassets/AppIcon.appiconset/AppIcon.png'
image.save(output_path)
print(f"App icon saved to: {output_path}")
