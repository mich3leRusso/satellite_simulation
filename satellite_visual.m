% load satellite TLE  constellation 

% Define the scenario timeframe
startTime = datetime(2026, 6, 3, 12, 0, 0); % Start time
stopTime = startTime + days(1);             % Run for 1 day
sampleTime = 60;                           % Step size in seconds

sc = satelliteScenario(startTime, stopTime, sampleTime);

latSteps = -60:30:60;  % Span from southern to northern latitudes
lonSteps = -180:45:179; % Span across all longitudinal time zones

for lat = latSteps
    for lon = lonSteps
        name = sprintf("Grid_Lat%d_Lon%d", lat, lon);
        groundStation(sc, lat, lon, "Name", name, "MaskElevationAngle", 5);
    end
end

% Create the satellite scenario object
constellation_military = satellite(sc, "military.tle");
constellation_galileo = satellite(sc, "galileo.tle");

% Open the satellite scenario viewer
viewer = satelliteScenarioViewer(sc);

%Play the scenario to animate the orbits
play(sc, PlaybackSpeedMultiplier=60);