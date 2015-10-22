function bathCals(userData)
% plot the bath calibration information from the post-retrieval on board
% calibration bath.
% Return plots of the difference from the reference SBE unit and a table of
% means and standard deviations over the period selected.
%
% Inputs: 
%       userData  contains all the data relevant to the instruments
%                   loaded
%       gData     data from the input gui that called this routine
%
% Rebecca Cowley <rebecca.cowley@csiro.au>
% October, 2015

%
dat = userData.treePanelData;
%Get the instrument list:
itemp = cellfun(@(x) x, dat(:,4));
instList = cellstr([char(dat(itemp,1)) char(dat(itemp,2))]);
sets      = ones(numel(instList),1);
insnms = char(dat(itemp,1));


%create the dialog box
[refinst,ok] = listdlg('PromptString','Choose the reference instrument',...
    'SelectionMode','single','ListString',instList,'Name',...
    'Reference instrument');

if ok == 0 % no instrument chosen
    return;
end

userData.refInst = refinst;
%reset instList so that it doesn't include the reference instrument
instList(refinst) = [];
insnms(refinst,:) = [];
sets(refinst) = [];

%ref instrument chosen, now ask to select the instruments that were in the
%bath:
%make another input box:
f = figure(...
    'Name',        'Bath Calibrated Instruments',...
    'Visible',     'off',...
    'MenuBar'  ,   'none',...
    'Resize',      'off',...
    'WindowStyle', 'Modal',...
    'NumberTitle', 'off');

cancelButton  = uicontrol('Style',  'pushbutton', 'String', 'Cancel');
confirmButton = uicontrol('Style',  'pushbutton', 'String', 'Ok');

setCheckboxes  = [];

for k = 1:numel(instList)
    
    setCheckboxes(k) = uicontrol(...
        'Style',    'checkbox',...
        'String',   instList{k},...
        'Value',    1, ...
        'UserData', k);
    
end

% set all widgets to normalized for positioning
set(f,              'Units', 'normalized');
set(cancelButton,   'Units', 'normalized');
set(confirmButton,  'Units', 'normalized');
set(setCheckboxes,  'Units', 'normalized');

set(f,             'Position', [0.2 0.35 0.6 0.3]);
set(cancelButton,  'Position', [0.0 0.0  0.5 0.1]);
set(confirmButton, 'Position', [0.5 0.0  0.5 0.1]);

rowHeight = 0.9 / numel(instList);
for k = 1:numel(instList)
    
    rowStart = 1.0 - k * rowHeight;
    
    set(setCheckboxes (k), 'Position', [0.0 rowStart 0.6 rowHeight]);
end

% set back to pixels
set(f,              'Units', 'normalized');
set(cancelButton,   'Units', 'normalized');
set(confirmButton,  'Units', 'normalized');
set(setCheckboxes,  'Units', 'normalized');

% set widget callbacks
set(f,             'CloseRequestFcn',   @cancelCallback);
set(f,             'WindowKeyPressFcn', @keyPressCallback);
set(setCheckboxes, 'Callback',          @checkboxCallback);
set(cancelButton,  'Callback',          @cancelCallback);
set(confirmButton, 'Callback',          @confirmCallback);

set(f, 'Visible', 'on');

uiwait(f);

%now we know which instruments are in the cal bath ('sets').
% and we know the time range for checking the offsets (calx,caly)
% and we know the reference unit ('refinst').
plotcals


    function plotcals
        %plot the bath calibration data as a comparison
        %return the handle to the figure, h
        % now put them onto the same timebase to compare the temp offsets:
        %use the cal bath interval:
        iu = unique(insnms,'rows');
        
        ref = userData.sample_data{refinst};
        reftemp = ref.variables{ref.plotThisVar}.data;
        refti = ref.dimensions{1}.data;
        refdif = nanmedian(diff(refti));
        tmin1 = userData.calx(1);
        tmax1 = userData.calx(2);
        igood = (refti >= tmin1 & refti <= tmax1);
        if isfield(userData,'calx2')
            tmin2 = userData.calx2(1);
            tmax2 = userData.calx2(2);
            igood = (refti >= tmin1 & refti <= tmax1) ...
                | (refti >= tmin2 & refti <= tmax2);
        end
        
        data = userData.sample_data;
        data(refinst) = [];
        data = data(logical(sets));
        insnms = insnms(find(sets),:);
        %plot the calibration data for all temperature ranges by time:
        figure(1);clf;hold on
        %need a figure to plot diffs by instrument type:
        figure(2);clf;hold on
        cc = parula(numel(data));
        cb = parula(size(iu,1));
        clear h h2
        mrk = {'+','o','*','.','x','s','d','^','>','<','p','h','+','o'};

        for a = 1:numel(data)
            insti = data{a}.dimensions{1}.data;
            temp = data{a}.variables{data{a}.plotThisVar}.data;
            igood2 = (insti >= tmin1 & insti <= tmax1);
            if isfield(userData,'calx2')
                igood2 = insti >= tmin1 & insti <= tmax1 ...
                    | (insti >= tmin2 & insti <= tmax2);
            end
            if sum(igood2) > 0
                %need the largest time diff between ref and each ins as timebase:
                insdif = nanmedian(diff(insti));
                if refdif > insdif
                    tbase = refti(igood);
                    caldat = reftemp(igood);
                    insdat = match_timebase(tbase,insti(igood2),temp(igood2));
                else
                    tbase = insti(igood2);
                    insdat = temp(igood2);
                    caldat = match_timebase(tbase,refti(igood),reftemp(igood));
                end
                %plot only the regions of comparison
                ii = tbase >= tmin1 & tbase <= tmax1;
                figure(1)
                if a == 1
                    h(a) = plot(tbase(ii),caldat(ii),'kx-','linewidth',2);
                end
                h(a) = plot(tbase(ii),insdat(ii),'x-','color',cc(a,:));
                
                if isfield(userData,'calx2')
                    ij = tbase >= tmin2 & tbase <= tmax2;
                    if a == 1
                        h2(a) = plot(tbase(ij),caldat(ij),'kx-','linewidth',2);
                    end
                    h2(a) = plot(tbase(ij),insdat(ij),'x-','color',cc(a,:));
                end
                
                %plot differences by instrument type
                figure(2)
                ik = strcmp(strtrim(insnms(a,:)),cellstr(iu)); %find the instrument group
                h = plot(caldat(ii),insdat(ii)-caldat(ii),'marker',mrk{ik},'color',cb(ik,:));
                text(double(h.XData(end)),double(h.YData(end)),iu(ik,:))
                if isfield(userData,'calx2')
                    h = plot(caldat(ij),insdat(ij)-caldat(ij),'marker',mrk{ik},'color',cb(ik,:));
                    text(double(h.XData(end)),double(h.YData(end)),iu(ik,:))
                end
                
                
            end
        end
        figure(1)
        grid on
        xlabel('Time')
        ylabel('Temperature \circC')
        datetick
        legend(h,instList(find(sets),:))
        title('Bath Calibrations')
        figure(2)
        
        legend(iu)
        title('Calibration bath temperature offsets from reference instrument')
        xlabel('Bath temperature \circC')
        ylabel('Temperature offset \circC')
        grid on
    end


    function keyPressCallback(source,ev)
        %KEYPRESSCALLBACK If the user pushes escape/return while the dialog has
        % focus, the dialog is cancelled/confirmed. This is done by delegating
        % to the cancelCallback/confirmCallback functions.
        %
        if     strcmp(ev.Key, 'escape'), cancelCallback( source,ev);
        elseif strcmp(ev.Key, 'return'), confirmCallback(source,ev);
        end
    end

    function cancelCallback(source,ev)
        %CANCELCALLBACK Cancel button callback. Discards user input and closes the
        % dialog .
        %
        sets(:)    = 0;
        delete(f);
    end

    function confirmCallback(source,ev)
        %CONFIRMCALLBACK. Confirm button callback. Closes the dialog.
        %
        delete(f);
    end

    function checkboxCallback(source, ev)
        %CHECKBOXCALLBACK Called when a checkbox selection is changed.
        %
        idx = get(source, 'UserData');
        val = get(source, 'Value');
        
        sets(idx) = val;
        
    end

end

