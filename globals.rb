require 'solar_integration/configuration.rb'

def to_radian(degree)
  return degree * Math::PI / 180
end

def to_degree(radian)
  return radian * 180 / Math::PI
end

X_AXIS = Geom::Vector3d.new(1, 0, 0)
Y_AXIS = Geom::Vector3d.new(0, 1, 0)
Z_AXIS = Geom::Vector3d.new(0, 0, 1)
ORIGIN = Geom::Point3d.new(0, 0, 0)
ECLIPTIC_ANGLE = 23.4

INSTALLATION_FOLDER = 'Plugins/solar_integration'