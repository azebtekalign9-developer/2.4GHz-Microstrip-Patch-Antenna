clear;
close all;
clc;

% ================================================================
% 2.4 GHz inset-fed rectangular microstrip patch antenna
% GNU Octave + openEMS
% Coordinates are in mm; unit converts them to meters in openEMS.
% This script generates REAL simulation results; it does not force
% the antenna to meet any preselected S11, gain, or bandwidth value.
% ================================================================

%% 1) OPENEMS PATHS (edit these only if openEMS is installed elsewhere)
addpath(genpath('C:\openEMS\matlab'));
addpath(genpath('C:\openEMS\openEMS\matlab'));

% Check that the main functions can be found
if exist('InitFDTD','file') == 0 || exist('RunOpenEMS','file') == 0
    error(['openEMS MATLAB/Octave functions were not found. Check the ' ...
           'two addpath lines at the top of this script.']);
end

physical_constants;

%% 2) PROJECT FOLDER
Sim_Path = fullfile(pwd, 'Patch24GHz_Portfolio');
Sim_CSX  = 'patch24GHz.xml';
if ~exist(Sim_Path, 'dir')
    mkdir(Sim_Path);
end
unit = 1e-3;  % all geometry coordinates below are in millimeters

%% 3) DESIGN PARAMETERS
f0   = 2.4e9;      % target frequency (Hz)
fc   = 1.0e9;      % Gaussian excitation bandwidth parameter (Hz)
epsR = 3.38;       % substrate relative permittivity
h    = 1.524;      % substrate thickness (mm)
tand = 0.001;      % approximate dielectric loss tangent

% Patch dimensions (mm). These are starting design values, not a guarantee
% that the simulated resonance will be exactly 2.4 GHz.
patch_L = 33.56;   % along x, feed enters from the negative-x edge
patch_W = 42.23;   % along y
sub_L   = 80;      % substrate length along x
sub_W   = 80;      % substrate width along y
feed_W  = 3.52;    % feed line width
inset_D = 10.3;    % inset depth into patch
inset_G = 1.0;     % gap on each side of feed within the inset notch

xPatchL = -patch_L/2;
xPatchR =  patch_L/2;
yPatchL = -patch_W/2;
yPatchR =  patch_W/2;
xSubL   = -sub_L/2;
xSubR   =  sub_L/2;
ySubL   = -sub_W/2;
ySubR   =  sub_W/2;
xInset  = xPatchL + inset_D;
feedHalf = feed_W/2;
notchHalf = feedHalf + inset_G;

% Feed reaches the edge of the substrate, then runs into the inset notch.
xFeedL = xSubL;
xFeedR = xInset;

% Lumped port is just inside the substrate edge, not on the outer boundary.
port_x1 = xSubL + 0.5;
port_x2 = xSubL + 1.5;

% Approximate conductivity equivalent for dielectric loss at f0.
% If your installed version rejects 'Kappa', remove that property and
% explicitly describe the substrate as lossless in the report.
kappa = 2*pi*f0*EPS0*epsR*tand;

fprintf('\n--- Antenna dimensions ---\n');
fprintf('Target frequency: %.3f GHz\n', f0/1e9);
fprintf('Patch: %.2f mm (x) x %.2f mm (y)\n', patch_L, patch_W);
fprintf('Substrate/ground: %.2f mm x %.2f mm\n', sub_L, sub_W);
fprintf('Substrate thickness: %.3f mm\n', h);
fprintf('Feed width: %.2f mm; inset depth: %.2f mm; inset gap: %.2f mm\n', feed_W, inset_D, inset_G);
fprintf('Feed begins at substrate edge x = %.2f mm\n', xFeedL);

%% 4) FDTD SETTINGS
FDTD = InitFDTD('NrTS', 80000, 'EndCriteria', 1e-5);
FDTD = SetGaussExcite(FDTD, f0, fc);
FDTD = SetBoundaryCond(FDTD, {'PML_8','PML_8','PML_8','PML_8','PML_8','PML_8'});

%% 5) MATERIALS AND GEOMETRY
CSX = InitCSX();

CSX = AddMaterial(CSX, 'Substrate');
CSX = SetMaterialProperty(CSX, 'Substrate', 'Epsilon', epsR, 'Kappa', kappa);
CSX = AddMetal(CSX, 'Patch');
CSX = AddMetal(CSX, 'Ground');

% Dielectric substrate, from z=0 to z=h
CSX = AddBox(CSX, 'Substrate', 1, ...
    [xSubL ySubL 0], [xSubR ySubR h]);

% Ground plane on the bottom surface (z=0)
CSX = AddBox(CSX, 'Ground', 10, ...
    [xSubL ySubL 0], [xSubR ySubR 0]);

% Inset-fed patch: build three copper rectangles around an open notch.
% Upper patch section
CSX = AddBox(CSX, 'Patch', 10, ...
    [xPatchL notchHalf h], [xPatchR yPatchR h]);
% Lower patch section
CSX = AddBox(CSX, 'Patch', 10, ...
    [xPatchL yPatchL h], [xPatchR -notchHalf h]);
% Inner bridge section closes the patch beyond the inset notch
CSX = AddBox(CSX, 'Patch', 10, ...
    [xInset -notchHalf h], [xPatchR notchHalf h]);

% Feed line: from the substrate edge to the end of the inset notch.
CSX = AddBox(CSX, 'Patch', 10, ...
    [xFeedL -feedHalf h], [xFeedR feedHalf h]);

% Lumped 50-ohm port spans ground-to-feed vertically inside the substrate.
[CSX, port] = AddLumpedPort(CSX, 5, 1, 50, ...
    [port_x1 -feedHalf 0], [port_x2 feedHalf h], [0 0 1], true);

%% 6) NEAR-FIELD TO FAR-FIELD BOX
% Must enclose the entire substrate/antenna, while staying inside the PML.
[CSX, NF2FFBox] = CreateNF2FFBox(CSX, 'nf2ff', ...
    [-45 -45 -5], [45 45 10]);

%% 7) MESH
% Start with moderate base spacing, then insert exact geometry/port/NF2FF
% boundaries. SmoothMesh fills large gaps while preserving key coordinates.
mesh.x = unique([-60:5:60, xSubL, xSubR, -45, 45, xPatchL, xPatchR, ...
                 xFeedL, xFeedR, xInset, port_x1, port_x2]);
mesh.y = unique([-60:5:60, ySubL, ySubR, -45, 45, yPatchL, yPatchR, ...
                 -notchHalf, -feedHalf, 0, feedHalf, notchHalf]);
mesh.z = unique([-20:5:40, -5, 0, h/2, h, 5, 10]);
mesh.x = sort(unique(mesh.x));
mesh.y = sort(unique(mesh.y));
mesh.z = sort(unique(mesh.z));
% IMPORTANT: openEMS SmoothMesh expects a mesh STRUCT with x/y/z fields,
% not an individual vector. Passing mesh.x causes the 'x/(r) direction not found' error.
mesh = SmoothMesh(mesh, 2.5, 1.5);
CSX = DefineRectGrid(CSX, unit, mesh);

%% 8) WRITE MODEL AND DISPLAY GEOMETRY
WriteOpenEMS(fullfile(Sim_Path, Sim_CSX), FDTD, CSX);
fprintf('\nGeometry exported to: %s\n', fullfile(Sim_Path, Sim_CSX));

try
    figure('Name', 'Antenna Geometry - openEMS', 'NumberTitle', 'off');
    CSXGeomPlot(fullfile(Sim_Path, Sim_CSX));
catch geomErr
    fprintf('Geometry viewer did not open: %s\n', geomErr.message);
end

%% 9) RUN SIMULATION
fprintf('\nStarting openEMS simulation. This may take some time...\n');
RunOpenEMS(Sim_Path, Sim_CSX, '--verbose=3');
fprintf('openEMS run returned. Checking port data...\n');

portFiles = dir(fullfile(Sim_Path, 'port*'));
if isempty(portFiles)
    error(['No port result files were found in %s. Do not trust any plots yet. ' ...
           'Check the openEMS log for port-domain, mesh, or simulation errors.'], Sim_Path);
end

%% 10) POST-PROCESS S11 AND INPUT IMPEDANCE
freq = linspace(2.0e9, 3.0e9, 1001);
port = calcPort(port, Sim_Path, freq);

s11 = port.uf.ref ./ port.uf.inc;
zin = port.uf.tot ./ port.if.tot;
s11dB = 20*log10(max(abs(s11), 1e-12));
[minS11, idxMin] = min(s11dB);
fRes = freq(idxMin);
zinRes = zin(idxMin);

% -10 dB bandwidth, using the largest contiguous region containing the minimum
below10 = s11dB <= -10;
leftIdx = idxMin;
rightIdx = idxMin;
while leftIdx > 1 && below10(leftIdx-1)
    leftIdx = leftIdx - 1;
end
while rightIdx < numel(freq) && below10(rightIdx+1)
    rightIdx = rightIdx + 1;
end
if any(below10)
    fLow = freq(leftIdx);
    fHigh = freq(rightIdx);
    bwHz = fHigh - fLow;
    fracBW = 100*bwHz/fRes;
else
    fLow = NaN; fHigh = NaN; bwHz = NaN; fracBW = NaN;
end

fprintf('\n--- RESULTS FROM THIS SIMULATION ---\n');
fprintf('Minimum S11: %.2f dB at %.4f GHz\n', minS11, fRes/1e9);
fprintf('Input impedance at minimum-S11 frequency: %.2f + j%.2f ohm\n', real(zinRes), imag(zinRes));
if ~isnan(bwHz)
    fprintf('-10 dB bandwidth: %.2f MHz (%.3f to %.3f GHz), fractional BW %.2f%%\n', bwHz/1e6, fLow/1e9, fHigh/1e9, fracBW);
else
    fprintf('The S11 curve did not cross -10 dB in the scanned band.\n');
end

%% 11) S11 PLOT (interactive figure; zoom/pan using the figure toolbar)
fig1 = figure('Name', 'S11 Return Loss', 'NumberTitle', 'off', 'Color', 'w');
plot(freq/1e9, s11dB, 'b-', 'LineWidth', 1.8);
hold on;
plot([freq(1) freq(end)]/1e9, [-10 -10], 'r--', 'LineWidth', 1.2);
plot(fRes/1e9, minS11, 'ro', 'MarkerFaceColor', 'r', 'MarkerSize', 6);
grid on; box on;
xlabel('Frequency (GHz)'); ylabel('S_{11} (dB)');
title('Return Loss / Reflection Coefficient');
legend('S_{11}', '-10 dB reference', 'Minimum S_{11}', 'Location', 'best');
xlim([freq(1) freq(end)]/1e9);
text(fRes/1e9, minS11, sprintf('  %.3f GHz, %.2f dB', fRes/1e9, minS11), 'VerticalAlignment', 'bottom');
print(fig1, fullfile(Sim_Path, 'S11_ReturnLoss.png'), '-dpng', '-r200');

%% 12) INPUT IMPEDANCE PLOT
fig2 = figure('Name', 'Input Impedance', 'NumberTitle', 'off', 'Color', 'w');
plot(freq/1e9, real(zin), 'b-', 'LineWidth', 1.8); hold on;
plot(freq/1e9, imag(zin), 'r--', 'LineWidth', 1.8);
plot(fRes/1e9, real(zinRes), 'bo', 'MarkerFaceColor', 'b');
grid on; box on;
xlabel('Frequency (GHz)'); ylabel('Input impedance (Ohm)');
title('Input Impedance versus Frequency');
legend('Real(Z_{in})', 'Imag(Z_{in})', 'At minimum S_{11}', 'Location', 'best');
xlim([freq(1) freq(end)]/1e9);
print(fig2, fullfile(Sim_Path, 'InputImpedance.png'), '-dpng', '-r200');

%% 13) FAR-FIELD / RADIATION PATTERN
% Use radians as required by CalcNF2FF. Two principal-plane cuts: phi=0 and 90 deg.
theta = (0:2:180) * pi/180;
phiCuts = [0 90] * pi/180;
fprintf('\nCalculating far-field pattern at %.4f GHz...\n', fRes/1e9);
nf2ff = CalcNF2FF(NF2FFBox, Sim_Path, fRes, theta, phiCuts, 'Mode', 1);

% Standard openEMS plotting functions, when available in the installed version.
try
    fig3 = figure('Name', 'Radiation Pattern - Principal Plane Cuts', 'NumberTitle', 'off', 'Color', 'w');
    plotFFdB(nf2ff, 'xaxis', 'theta', 'param', [1 2]);
    grid on; box on;
    title(sprintf('Radiation Pattern at %.4f GHz', fRes/1e9));
    legend('phi = 0 deg', 'phi = 90 deg', 'Location', 'best');
    print(fig3, fullfile(Sim_Path, 'RadiationPattern_2D.png'), '-dpng', '-r200');
catch ffErr
    fprintf('plotFFdB was unavailable or failed: %s\n', ffErr.message);
    % Fallback: plot normalized E-field cuts if the output arrays have expected dimensions.
    if isfield(nf2ff, 'E_norm') && ~isempty(nf2ff.E_norm)
        En = nf2ff.E_norm{1};
        fig3 = figure('Name', 'Normalized Far-Field Magnitude', 'NumberTitle', 'off', 'Color', 'w');
        if isvector(En)
            En = En(:);
            plot(theta(1:min(numel(theta),numel(En)))*180/pi, ...
                 20*log10(max(En(1:min(numel(theta),numel(En)))/max(En),1e-6)), 'LineWidth', 1.8);
        else
            plot(theta*180/pi, 20*log10(max(En(:,1)/max(En(:)),1e-6)), 'LineWidth', 1.8); hold on;
            if size(En,2) >= 2
                plot(theta*180/pi, 20*log10(max(En(:,2)/max(En(:)),1e-6)), '--', 'LineWidth', 1.8);
            end
        end
        grid on; box on; ylim([-40 0]);
        xlabel('Theta (degrees)'); ylabel('Normalized |E| (dB)');
        title(sprintf('Normalized Radiation Pattern at %.4f GHz', fRes/1e9));
        print(fig3, fullfile(Sim_Path, 'RadiationPattern_2D.png'), '-dpng', '-r200');
    end
end

try
    fig4 = figure('Name', '3D Radiation Pattern', 'NumberTitle', 'off', 'Color', 'w');
    plotFF3D(nf2ff, 'logscale', -25);
    title(sprintf('3D Far-Field Pattern at %.4f GHz', fRes/1e9));
    print(fig4, fullfile(Sim_Path, 'RadiationPattern_3D.png'), '-dpng', '-r200');
catch ff3Err
    fprintf('3D pattern helper unavailable or failed: %s\n', ff3Err.message);
end

%% 14) SAVE NUMERICAL DATA FOR REPORT / PORTFOLIO
csvFile = fullfile(Sim_Path, 'FrequencyResults.csv');
fid = fopen(csvFile, 'w');
if fid >= 0
    fprintf(fid, 'Frequency_Hz,S11_dB,S11_Magnitude,Zin_Real_Ohm,Zin_Imag_Ohm\n');
    for k = 1:numel(freq)
        fprintf(fid, '%.9g,%.6f,%.9g,%.6f,%.6f\n', ...
            freq(k), s11dB(k), abs(s11(k)), real(zin(k)), imag(zin(k)));
    end
    fclose(fid);
end

summaryFile = fullfile(Sim_Path, 'SimulationSummary.txt');
fid = fopen(summaryFile, 'w');
if fid >= 0
    fprintf(fid, '2.4 GHz Microstrip Patch Antenna - GNU Octave + openEMS\n');
    fprintf(fid, 'Target frequency: %.6f GHz\n', f0/1e9);
    fprintf(fid, 'Simulated minimum-S11 frequency: %.6f GHz\n', fRes/1e9);
    fprintf(fid, 'Minimum S11: %.3f dB\n', minS11);
    fprintf(fid, 'Zin at minimum S11: %.3f + j%.3f Ohm\n', real(zinRes), imag(zinRes));
    fprintf(fid, 'Patch dimensions: %.3f x %.3f mm\n', patch_L, patch_W);
    fprintf(fid, 'Substrate: %.3f x %.3f x %.3f mm, epsilon_r=%.3f, tan_delta=%.4f\n', sub_L, sub_W, h, epsR, tand);
    if ~isnan(bwHz)
        fprintf(fid, '-10 dB bandwidth: %.3f MHz\n', bwHz/1e6);
        fprintf(fid, '-10 dB band: %.6f to %.6f GHz\n', fLow/1e9, fHigh/1e9);
        fprintf(fid, 'Fractional bandwidth: %.3f %%\n', fracBW);
    else
        fprintf(fid, 'No -10 dB bandwidth found within the simulated frequency range.\n');
    end
    if isfield(nf2ff, 'Dmax') && ~isempty(nf2ff.Dmax)
        fprintf(fid, 'Maximum directivity reported by NF2FF: %.3f dBi\n', nf2ff.Dmax(1));
    end
    fclose(fid);
end

fprintf('\nFiles saved in:\n%s\n', Sim_Path);
fprintf('Expected files include S11_ReturnLoss.png, InputImpedance.png, radiation plots, FrequencyResults.csv, and SimulationSummary.txt.\n');
fprintf('Reminder: use only these actual outputs in your portfolio; do not substitute illustrative values.\n');
