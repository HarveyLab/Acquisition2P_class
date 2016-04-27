function cbPassThroughKeypressToMain(sel, src, evt)
% Attach this function as the WindowKeyPressFcn callback to any figure
% from which you want to pass key presses to the main window (i.e. if a key
% is pressed when that figure has focus, it is as if the main figure had
% focus when the key was pressed).
sel.cbKeypress(src, evt);