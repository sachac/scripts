#!/usr/bin/env python

import numpy as np
import argparse
import imutils
import cv2

ap = argparse.ArgumentParser()
ap.add_argument("-i", "--input", help = "input file")
ap.add_argument("-o", "--output", help = "output file")
args = vars(ap.parse_args())

def order_points(cardContour):
  pts = cardContour.reshape(4, 2)
  rect = np.zeros((4, 2), dtype = "float32")
  s = pts.sum(axis = 1)
  rect[0] = pts[np.argmin(s)]
  rect[2] = pts[np.argmax(s)]
  diff = np.diff(pts, axis = 1)
  rect[1] = pts[np.argmin(diff)]
  rect[3] = pts[np.argmax(diff)]
  return rect    

# http://www.pyimagesearch.com/2014/08/25/4-point-opencv-getperspective-transform-example/
def four_point_transform(image, pts):
   # obtain a consistent order of the points and unpack them
   # individually
   rect = order_points(pts)
   (tl, tr, br, bl) = rect
   # compute the width of the new image, which will be the
   # maximum distance between bottom-right and bottom-left
   # x-coordiates or the top-right and top-left x-coordinates
   widthA = np.sqrt(((br[0] - bl[0]) ** 2) + ((br[1] - bl[1]) ** 2))
   widthB = np.sqrt(((tr[0] - tl[0]) ** 2) + ((tr[1] - tl[1]) ** 2))
   maxWidth = max(int(widthA), int(widthB))

   # compute the height of the new image, which will be the
   # maximum distance between the top-right and bottom-right
   # y-coordinates or the top-left and bottom-left y-coordinates
   heightA = np.sqrt(((tr[0] - br[0]) ** 2) + ((tr[1] - br[1]) ** 2))
   heightB = np.sqrt(((tl[0] - bl[0]) ** 2) + ((tl[1] - bl[1]) ** 2))
   maxHeight = max(int(heightA), int(heightB))

   # now that we have the dimensions of the new image, construct
   # the set of destination points to obtain a "birds eye view",
   # (i.e. top-down view) of the image, again specifying points
   # in the top-left, top-right, bottom-right, and bottom-left
   # order
   dst = np.array([
           [0, 0],
           [maxWidth - 1, 0],
           [maxWidth - 1, maxHeight - 1],
           [0, maxHeight - 1]], dtype = "float32")

   # compute the perspective transform matrix and then apply it
   M = cv2.getPerspectiveTransform(rect, dst)
   warped = cv2.warpPerspective(image, M, (maxWidth, maxHeight))

   # return the warped image
   return warped

def make_landscape(image):
  if image.shape[0] > image.shape[1]:
    rows = image.shape[0]
    cols = image.shape[1]
    M = cv2.getRotationMatrix2D((cols/2,rows/2),90,1)
    image = cv2.warpAffine(image,M,(cols,rows))
  return image

def prepare_grayscale_for_analysis(image):
  image = image.copy()
  new_height = 500
  ratio = image.shape[0] * 1.0 / new_height
  image = imutils.resize(image, height = new_height)
  hsv = cv2.cvtColor(image, cv2.COLOR_BGR2HSV)
  (hue, saturation, values) = cv2.split(image)
  gray = hue
  #gray = cv2.GaussianBlur(gray, (5, 5), 0)
  gray = cv2.bilateralFilter(gray, 20, 17, 17)
  kernel = np.ones((5,5),np.uint8)
  gray = cv2.dilate(gray, kernel, iterations = 1)
  gray = cv2.erode(gray, kernel, iterations = 2)
  return gray, ratio

def detect_contour(gray):
  edges = cv2.Canny(gray, 40, 200)
  (contours, _) = cv2.findContours(edges.copy(), cv2.RETR_TREE, cv2.CHAIN_APPROX_SIMPLE)
  contours = sorted(contours, key = cv2.contourArea, reverse = True)
  cardContour = contours[0]
  peri = cv2.arcLength(cardContour, True)
  approx = cv2.approxPolyDP(cardContour, 0.02 * peri, True)
  return approx

# construct the argument parse and parse the arguments
# ap = argparse.ArgumentParser()
# ap.add_argument("-i", "--image", required=True,
# 	help="path to input image file")
# args = vars(ap.parse_args())
 
# load the image from disk
import sys
print "Loading image..."
image = cv2.imread(args["input"])
print "Rotating if needed..."
image = make_landscape(image)
print "Preparing grayscale for analysis..."
gray, ratio = prepare_grayscale_for_analysis(image)

print "Finding contours..."
#ret, gray = cv2.threshold(gray, 127, 255, cv2.THRESH_BINARY)
#cv2.imshow("gray", gray)
approx = detect_contour(gray)
largeContour = (approx * ratio).astype(int)
#cv2.drawContours(out, [approx], 0, 255, -1)
# cv2.drawContours(orig, [largeContour], 0, 255, -1)

print "Transforming rectangle..."
out = four_point_transform(image, largeContour)
out = cv2.resize(out, (1500,900))
out = cv2.cvtColor(out, cv2.COLOR_BGR2GRAY)

print "Preparing output image..."
result, out = cv2.threshold(out, 0, 255, cv2.THRESH_BINARY + cv2.THRESH_OTSU)
# out = cv2.adaptiveThreshold(out, 255, cv2.ADAPTIVE_THRESH_MEAN_C, cv2.THRESH_BINARY, 101, 2)
out = cv2.GaussianBlur(out, (3, 3), 0)
out = cv2.cvtColor(out, cv2.COLOR_GRAY2BGR)
cv2.imwrite(args["output"], out)
cv2.imshow("image", out)
#cv2.imshow("image", gray)
cv2.waitKey(0)

