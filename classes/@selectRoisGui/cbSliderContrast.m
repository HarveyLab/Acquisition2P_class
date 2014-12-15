function cbSliderContrast(sel,~,~)

img = sel.disp.img;
for c = 1:size(img, 3);
    % Perform scaling on each color channel:
    img(:,:,c) = mat2gray(img(:,:,c), [get(sel.h.ui.sliderBlack, 'Value'), get(sel.h.ui.sliderWhite, 'Value')]);
end
set(sel.h.img.overview, 'cdata', img);

end