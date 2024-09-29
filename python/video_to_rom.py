"""
video_to_rom.py

This Python script is used to convert moving images (gifs, videos, etc)
to a output.txt file that is pasted in the ROM of the FPGA.

It starts by converting moving images to an array of RGB values.
From there, the RGB values are converted to YCbCr.
For each frame of the video, code is generated for
assigning colours to pixels in Verilog.

In order to run this file, create a virtual environment and run

pip install -r requirements.txt

Ensure that you have changed the INPUT_VIDEO path to a valid video or gif
"""

import cv2
from PIL import Image
import numpy as np
import os

# This value needs to be changed in order to run this file.
INPUT_VIDEO = "./path_to_video_or_gif"

def write_to_file(image_path, output_file, count):
    img = Image.open(image_path).convert('RGB')
    rgb_array = np.array(img)
    
    # Split RGB channels
    r = rgb_array[:, :, 0].astype(np.float32)
    g = rgb_array[:, :, 1].astype(np.float32)
    b = rgb_array[:, :, 2].astype(np.float32)
    
    # RGB to YCbCr conversion formulas based on https://en.wikipedia.org/wiki/YCbCr
    # There is another consideration that the YCbCr colourspace is within the range
    # of 0x4 and 0x3FF
    y = (np.round((0.299 * r + 0.587 * g + 0.114 * b) * 1016 / 255 + 4))
    cb = (np.round((128 + (-0.169 * r - 0.331 * g + 0.5 * b)) * 1016 / 255 + 4 ))
    cr = (np.round((128 + (0.5 * r - 0.419 * g - 0.081 * b)) * 1016 / 255 + 4 ))

    # Ensure the values fit within the range of 4 and 1020 and 10 bits
    y_10bit = np.clip(y, 4, 1020).astype(np.uint32)
    cb_10bit = np.clip(cb, 4, 1020).astype(np.uint32)
    cr_10bit = np.clip(cr, 4, 1020).astype(np.uint32)
    
    ycbcr_array = np.stack((y_10bit, cb_10bit, cr_10bit), axis=-1)
    
    # Open file for writing
    with open(output_file, 'a') as stream_file:
        height, width, _ = ycbcr_array.shape
        
        for ht in range(height):
            for wt in range(width):
                # Extract Y, Cb, Cr values
                y, cb, cr = ycbcr_array[ht, wt]
                bitshift = (y << 20) + (cb << 10) + (cr)

                # Write values to the .hex file
                stream_file.write(f"ross[{count}]=30'd{bitshift};\n")
                count += 1
    stream_file.close()
    return count

# Capture video data
video_capture = cv2.VideoCapture(INPUT_VIDEO)
video_capture.set(cv2.CAP_PROP_FPS, 59.94)

frame_no = 0
global_count = 0

loop = True
while loop:
    frame_is_read, frame = video_capture.read()

    if frame_is_read:
        # Write to bitmap image files
        cv2.imwrite(f"frame{str(frame_no)}.bmp", frame)
        frame_no += 1
    else:
        loop = False

if os.path.isfile("output.txt"):
    os.remove("output.txt")

for i in range(frame_no):
    # Write to file for each frame
    image_path = f"frame{i}.bmp"
    global_count = write_to_file(image_path, "output.txt", global_count)
    os.remove(f"frame{str(i)}.bmp")
