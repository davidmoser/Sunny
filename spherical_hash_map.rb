
# categorize and retrieve values according to the spherical angles that the
# polygon covers (as a chain of line segments)
# each value may up in multiple 'angle-bins' covered by its chain
class SphericalHashMap
  def initialize
    @map = Hash.new([]) # empty list is the default
  end
  
  def add_value(polygon, value)
    azimuth_hashes = AzimuthHashInterval.new(polygon)
    polar_hashes = PolarHashInterval.new(polygon)
    combined_hashes = azimuth_hashes.get_hash_array.product polar_hashes.get_hash_array
    combined_hashes.each{|h| @map[h].push value}
  end
  
  def get_values(point)
    azimuth_hash = AzimuthHashInterval.calculate_hash(point)
    polar_hash = PolarHashInterval.calculate_hash(point)
    return @map[[azimuth_hash, polar_hash]]
  end
end

# determines the range of polar angle that a polygon covers
# the polygon needs to be in a plane and convex for the
# north/south pole check to work
class PolarHashInterval
  @@angular_resolution = 10 * 2 * Math::PI / 180
  @@vertical = Geom::Vector3d(0,0,1)
  
  def initialize(polygon)
    @pl_min, @pl_max = polygon.collect{|p| self.class.calculate_polar_angle(p)}.minmax
    
    normals = calculate_normals(polygon)
    # polygon surrounds north pole
    if normals.collect{|n| n[2]>0}.reduce(:&)
      @pl_min = 0
      return
    end
    # polygon surrounds south pole
    if normals.collect{|n| n[2]<=0}.reduce(:&)
      @pl_max = Math::PI
      return
    end
    # check if there's a polar angle max/min inside a segment
    segments.zip pyramid do |s, n|
      if is_extremal_angle_inside_segment(n, s)
        if s[0]+s[1]>0
          # min angle inside segment
          @pl_min = [@pl_min, (calculate_polar_angle(normal)-Math::PI/2).abs].min
        else
          # max angle inside segment
          @pl_max = [@pl_max, (calculate_polar_angle(normal)-Math::PI/2).abs].max
        end
      end
    end
  end
  
  def calculate_normals(polygon)
    normals = []
    polygon.each.with_index do |p,i|
      normals.push p*polygon[(i+1)%polygon.length]
    end
    # make sure normals point inwards, assumes convexity
    if normals[0] % polygon[2] < 0
      normals.collect! {|n| n.reverse}
    end
    return normals
  end
  
  def self.calculate_hash(vector)
    return self.as_hash(self.calculate_polar_angle(vector))
  end
  
  def self.calculate_polar_angle(vector)
    rho = Math::hypot(vector[0], vector[1])
    return Math::atan2(rho, vector[2])
  end
  
  def self.as_hash(polar_angle)
    return (polar_angle/@@angular_resolution).floor
  end
  
  def is_extremal_angle_inside_segment(normal, segment)
    # normal to plane where the polar angle of the segment is extremal
    extremal_normal = normal * @@vertical
    # are segment points on same side of plane with extreme polar angles
    return (extremal_normal % segment[0])*(extremal_normal % segment[1])>=0
  end
  
  def get_hash_array()
    return self.class.as_hash(@pl_min)..self.class.as_hash(@pl_max).to_a
  end
end

# convert azimuth angles of a polygon
# to an array of integer hashes
class AzimuthHashInterval
  attr_reader :hash_array
  
  @@angular_resolution = 10 * 2 * Math::PI / 180
  def initialize(polygon)
    @az_current = self.class.calculate_azimuth(point)
    @az_min = @az_max = @az_current
    @loop_number = 0 # how many times have we looped/ crossed 0=2pi border
    polygon.each {|p| add(p)}
    add(polygon[0]) # close the polygon
    adjust_interval
    calculate_hash_array
  end
  
  def self.calculate_hash(point)
    return self.as_hash(self.calculate_azimuth(point))
  end
  
  def self.calculate_azimuth(point)
    return Math::atan2(point[1], point[0])
  end
  
  def self.as_hash(az)
    return (az/@@angular_resolution).floor
  end
  
  # adding segments while keeping track of how many times we looped
  # @min is always smaller than @max here
  def add(point)
    az_new = self.class.calculate_azimuth(point)
    az_new += @loop_number * 2 * Math::PI
    
    # check if we looped
    if az_new-@az_current>Math::PI
      az_new -= 2*Math::PI
      @loop_number -= 1
    elsif @az_current-az_new>Math::PI
      az_new += 2*Math::PI
      @loop_number += 1
    end
    # save adjusted value
    @az_current = az_new
    
    # possibly extend borders
    @az_min = [@az_min, az_new].min
    @az_max = [@az_max, az_new].max
  end
  
  # after adding the whole polygon: get back in 0-2pi boundaries
  # now @az_max maybe smaller than @az_min, i.e. one looping
  def adjust_interval
    if @az_max - @az_min >= 2*Math::PI
      # have come full circle
      @az_min = 0
      @az_max = 2*Math::PI
    else
      @az_max %= 2*Math::PI
      @az_min %= 2*Math::PI
    end
  end
  
  def calculate_hash_array
    if @az_min<=@az_max
      @hash_array = as_hash_array(@az_min, @az_max)
    else
      @hash_array = as_hash_array(0, @az_max) + as_hash_array(@az_min, 2*Math::PI)
    end
  end
  
  def as_hash_array(az1, az2)
    return self.class.as_hash(az1)..self.class.as_hash(az2).to_a
  end
end