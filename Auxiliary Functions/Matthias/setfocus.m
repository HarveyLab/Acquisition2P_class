function setfocus(h);
%
%
%  sample of a simple apporch to the set a focus to a uicontrol:
%  setfocus forces a mouseclick in the upper left corner of the
%  object with the handle h.
%  

% $Revision: 1.3 $
% $Date: 2002/06/27 12:41:01 $
% $Author: weber $

if nargin<1
    error('No input handle defined!')
end

if ~ishandle(h) 
    error('Input must be a handle!');
end


callback='';

% When the object is a 'uicontrol' the function of the object would be 
% executed. Therefore I have to set it to '', and set it back after the mouseclick

if strcmp(get(h, 'Type'), 'uicontrol')
    callback=get(h, 'Callback');
    set(h, 'Callback', '');
    drawnow; % Update the figure data
end


figh=get(h, 'Parent');
unit_root=get(0, 'Unit');
unit_fig=get(figh, 'Unit');
unit_obj=get(h, 'Unit');
set(0, 'Units', 'pixels');
set(figh, 'Units', 'pixels');
set(h, 'Units', 'pixels');
drawnow;

% get the current mouse pointer coordinates 
mouse_coord=get(0, 'PointerLocation');
if ~verLessThan('matlab', '8.4') && ~strcmp(figh.Type,'figure') %if older than 2014b
   figh = figh.CurrentFigure; 
end
fig_pos=get(figh, 'Position');
obj_pos=get(h, 'Position');

act_pos=fig_pos+obj_pos;
act_pos=act_pos(1:2);
act_pos(1)=act_pos(1)+3;
act_pos(2)=act_pos(2)+obj_pos(4)-7;

% set the mouse pointer to the upper left corner of the object
% (I did this for listboxes, to highlight the first entry)

set(0, 'PointerLocation', act_pos);

% mouseclick; %simulate the mouseclick

import java.awt.Robot;
import java.awt.event.*;
mouse = Robot;
mouse.mousePress(InputEvent.BUTTON1_MASK);
mouse.mouseRelease(InputEvent.BUTTON1_MASK);


%-----------------------------------------------------------------------------
% set all parameters that were changed back to the starting values

set(0, 'PointerLocation', mouse_coord);

if strcmp(get(h, 'Type'), 'uicontrol')
    drawnow;   % When there is no 'drawnow', the original Callback- String
               % will be executed, even the Callback String is set to '';
    set(h, 'Callback', callback);
end

set(0, 'Unit', unit_root);
set(figh, 'Unit', unit_fig);
set(h, 'Unit', unit_obj);
drawnow;