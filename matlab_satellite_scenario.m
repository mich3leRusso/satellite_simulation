%% =========================================================
%% 3 GALILEO-LIKE SATELLITES + GS RECEIVED I/Q (R2025b)
%% =========================================================

clear; clc; close all;

%% =========================================================
%% TIME SETUP
%% =========================================================
startTime  = datetime(2026,5,12,11,30,0);
stopTime   = startTime + hours(24);
sampleTime = 20;

sc = satelliteScenario(startTime, stopTime, sampleTime);
viewer = satelliteScenarioViewer(sc);
viewer.PlaybackSpeedMultiplier = 200;

%% =========================================================
%% GROUND STATION
%% Use the syntax available in R2025b
%% =========================================================
gs = groundStation(sc, 41.9, 12.5, Name="RomeGS");

%% =========================================================
%% 3 GALILEO-LIKE MEO SATELLITES
%% =========================================================
aGal = 29600e3;

satG1 = satellite(sc, aGal, 0.001, 56.0,   0,   0,   0, Name="G1");
satG2 = satellite(sc, aGal, 0.001, 56.0, 120,   0, 120, Name="G2");
satG3 = satellite(sc, aGal, 0.001, 56.0, 240,   0, 240, Name="G3");

%% =========================================================
%% GIMBALS
%% =========================================================
gG1_tx = gimbal(satG1, Name="G1_Tx");
gG2_tx = gimbal(satG2, Name="G2_Tx");
gG3_tx = gimbal(satG3, Name="G3_Tx");

gGS1 = gimbal(gs, Name="GS_Rx_G1");
gGS2 = gimbal(gs, Name="GS_Rx_G2");
gGS3 = gimbal(gs, Name="GS_Rx_G3");

%% =========================================================
%% TX / RX (E1‑like carrier)
%% =========================================================
fc  = 1.57542e9;
Rs  = 1.023e6;   % 1.023 Mcps (E1 chip rate)
txP = 14;       % 14 dBW

txG1 = transmitter(gG1_tx, ...
    Name="TxG1", ...
    Frequency=fc, ...
    Power=txP, ...
    BitRate=Rs, ...
    SystemLoss=2);

txG2 = transmitter(gG2_tx, ...
    Name="TxG2", ...
    Frequency=fc, ...
    Power=txP, ...
    BitRate=Rs, ...
    SystemLoss=2);

txG3 = transmitter(gG3_tx, ...
    Name="TxG3", ...
    Frequency=fc, ...
    Power=txP, ...
    BitRate=Rs, ...
    SystemLoss=2);

rxGS1 = receiver(gGS1, ...
    Name="RxGS1", ...
    GainToNoiseTemperatureRatio=18, ...
    RequiredEbNo=5, ...
    SystemLoss=2);

rxGS2 = receiver(gGS2, ...
    Name="RxGS2", ...
    GainToNoiseTemperatureRatio=18, ...
    RequiredEbNo=5, ...
    SystemLoss=2);

rxGS3 = receiver(gGS3, ...
    Name="RxGS3", ...
    GainToNoiseTemperatureRatio=18, ...
    RequiredEbNo=5, ...
    SystemLoss=2);

%% =========================================================
%% ANTENNAS (Gaussian)
%% =========================================================
gaussianAntenna(txG1, DishDiameter=0.8, ApertureEfficiency=0.65);
gaussianAntenna(txG2, DishDiameter=0.8, ApertureEfficiency=0.65);
gaussianAntenna(txG3, DishDiameter=0.8, ApertureEfficiency=0.65);

gaussianAntenna(rxGS1, DishDiameter=1.2, ApertureEfficiency=0.65);
gaussianAntenna(rxGS2, DishDiameter=1.2, ApertureEfficiency=0.65);
gaussianAntenna(rxGS3, DishDiameter=1.2, ApertureEfficiency=0.65);

%% =========================================================
%% POINTING
%% =========================================================
pointAt(gG1_tx, gs);
pointAt(gG2_tx, gs);
pointAt(gG3_tx, gs);

pointAt(gGS1, satG1);
pointAt(gGS2, satG2);
pointAt(gGS3, satG3);

%% =========================================================
%% LINKS
%% =========================================================
lnkG1 = link(txG1, rxGS1);
lnkG2 = link(txG2, rxGS2);
lnkG3 = link(txG3, rxGS3);

%% Link metrics
fprintf('\n--- G1 -> GS intervals ---\n');
disp(linkIntervals(lnkG1));

fprintf('\n--- EB/No for G1 -> GS ---\n');
[eG1, t] = ebno(lnkG1);
[eG2, ~] = ebno(lnkG2);
[eG3, ~] = ebno(lnkG3);

sn0_G1 = eG1 + 10*log10(txG1.BitRate);
sn0_thresh = rxGS1.RequiredEbNo + 10*log10(txG1.BitRate);

detectG1 = sn0_G1 > sn0_thresh;

figure;
plot(t, sn0_G1, 'LineWidth', 1.5); hold on;
%plot(t, sn0_G2, 'LineWidth', 1.5);
%plot(t, sn0_G3, 'LineWidth', 1.5);
yline(sn0_thresh, '--k', sprintf('Required S/N_0 = %.1f dBHz', sn0_thresh));
grid on; xlabel('Time'); ylabel('S/N_0 (dBHz)');
legend('G1 -> GS','G2 -> GS','G3 -> GS','Location','best');
title('Galileo‑like satellites to GS');

%% =========================================================
%% CHOOSE EPOCH
%% =========================================================
openIdx = find(isfinite(eG1) & detectG1, 1, 'first');
if isempty(openIdx)
    [~, openIdx] = max(sn0_G1);
end

tChosen = t(openIdx);
EbNoChosen_dB = eG1(openIdx);

fprintf('\nSelected epoch: %s\n', string(tChosen));
fprintf('Eb/No at GS for G1: %.2f dB\n', EbNoChosen_dB);

%% =========================================================
%% GENERATE PRN-LIKE E1‑STYLE BASEBAND
%% Same as in MathWorks GPS/GNSS examples
%% =========================================================
Fs = 4.092e6;           % 4.092 MHz sampling (standard GNSS‑style)
numSym = 4000;          % symbols / chips
sps = round(Fs/Rs);

% Random PN‑like sequence (±1)
rng('shuffle');
prn = 2*randi([0 1], numSym, 1) - 1;

% Upsample to match Fs/Rs
prn = upsample(prn, sps);

% RRC shaping
rrc = rcosdesign(0.35, 8, sps, 'sqrt');

% Pulse‑shaped baseband
txBaseband = conv(prn, rrc, 'same');
txBaseband = txBaseband / rms(txBaseband);

%% =========================================================
%% DOPPLER FROM GS–G1 GEOMETRY
%% =========================================================
[posG1, velG1, tStates] = states(satG1, CoordinateFrame="ecef");
gsLat = gs.Latitude;
gsLon = gs.Longitude;
gsAlt = gs.Altitude;
rGS = lla2ecef([gsLat, gsLon, gsAlt])';

[~, idxState] = min(abs(seconds(tStates - tChosen)));
rSat = posG1(:, idxState);
vSat = velG1(:, idxState);

losVec = rGS - rSat;
uLos = losVec / norm(losVec);
rangeRate = dot(vSat, uLos);

c = physconst("Lightspeed");
fd = -(rangeRate / c) * fc;

fprintf('Doppler at chosen epoch: %.2f Hz\n', fd);

%% =========================================================
%% BUILD GS-RECEIVED I/Q
%% Use Eb/N0 from link to set noise level
%% =========================================================
EbNoLin = 10^(EbNoChosen_dB/10);
snrLin  = EbNoLin * txG1.BitRate / Fs;

sigPow = mean(abs(txBaseband).^2, 1);
noiseVar = sigPow / snrLin;
noise = sqrt(noiseVar/2) * (randn(size(txBaseband)) + 1i*randn(size(txBaseband)));

n = 0:length(txBaseband)-1;
dopplerPhase = exp(1i*2*pi*fd*n./Fs);

rx_IQ = (txBaseband + noise) .* dopplerPhase;   % Complex I/Q at GS

%% =========================================================
%% PLOT GS‑RECEIVED I/Q
%% =========================================================
figure;
subplot(2,1,1);
plot(real(rx_IQ), 'LineWidth', 0.9); grid on;
xlabel('Sample'); ylabel('I'); title('GS received I (G1, E1‑style)');

subplot(2,1,2);
plot(imag(rx_IQ), 'LineWidth', 0.9); grid on;
xlabel('Sample'); ylabel('Q'); title('GS received Q (G1, E1‑style)');

%% Constellation
figure;
plot(real(rx_IQ), imag(rx_IQ), '.', 'MarkerSize', 3);
grid on; axis equal;
title('GS received I/Q constellation (G1)');

%% Spectrum
figure;
pwelch(rx_IQ, hamming(1024), 512, 2048, Fs, 'centered');
title('GS received spectrum (G1, E1‑style)');

%% Save I/Q for your GNSS‑style receiver
save('rx_IQ_G1_GS.mat', 'rx_IQ', 'Fs', 'tChosen', 'EbNoChosen_dB', 'fd');

%% =========================================================
%% PLAY SCENARIO
%% =========================================================
play(sc);