function cbSliderContrast(sel,~,~)

img = sel.disp.img;
img = mat2gray(img, [get(sel.h.ui.sliderBlack, 'Value'), get(sel.h.ui.sliderWhite, 'Value')]);
set(sel.h.img.overview, 'cdata', img);

end