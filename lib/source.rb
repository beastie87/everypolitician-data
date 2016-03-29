require 'csv'

class Source

  # Instantiate correct subclass based on instructions
  def self.instantiate(i)
    return Source::Membership.new(i) if i[:type] == 'membership'
    return Source::Person.new(i)     if i[:type] == 'person'
    return Source::Wikidata.new(i)   if i[:type] == 'wikidata'
    return Source::Group.new(i)      if i[:type] == 'group'
    return Source::OCD.new(i)        if i[:type] == 'ocd'
    return Source::Area.new(i)       if i[:type] == 'area-wikidata'
    return Source::Gender.new(i)     if i[:type] == 'gender'
    return Source::Positions.new(i)  if i[:type] == 'wikidata-positions'
    return Source::Term.new(i)       if i[:type] == 'term'
    raise "Don't know how to handle #{i[:type]} files (#{i})" 
  end

  def initialize(i)
    @instructions = i
  end

  def i(k)
    @instructions[k.to_sym]
  end

  def fields
    header_line = File.open(filename, &:gets) or abort "#{filename} is empty!".red
    ::CSV.parse_line(header_line).map { |h| remap(h.downcase) } 
  end

  def merge_instructions
    mi = i(:merge) or return []
    mi.class == Hash ? [mi] : mi
  end

  def is_memberships?
    false
  end

  def is_bios?
    false
  end

  # private
  REMAP = {
    area: %w(constituency region district place),
    area_id: %w(constituency_id region_id district_id place_id),
    biography: %w(bio blurb),
    birth_date: %w(dob date_of_birth),
    blog: %w(weblog),
    cell: %w(mob mobile cellphone),
    chamber: %w(house),
    death_date: %w(dod date_of_death),
    end_date: %w(end ended until to),
    executive: %w(post),
    family_name: %w(last_name surname lastname),
    fax: %w(facsimile),
    gender: %w(sex),
    given_name: %w(first_name forename),
    group: %w(party party_name faction faktion bloc block org organization organisation),
    group_id: %w( party_id faction_id faktion_id bloc_id block_id org_id organization_id organisation_id),
    image: %w(img picture photo photograph portrait),
    name: %w(name_en),
    patronymic_name: %w(patronym patronymic),
    phone: %w(tel telephone),
    source: %w(src),
    start_date: %w(start started from since),
    term: %w(legislative_period),
    website: %w(homepage href url site),
  }.each_with_object({}) { |(k, vs), mapped| vs.each { |v| mapped[v] = k } }

  def remap(str)
    REMAP[str.to_s] || str.to_sym
  end

  def filename
    i(:file)
  end
end

class Source::CSV < Source
  def as_table
    rows = []
    ::CSV.table(filename, converters: nil).each do |row|
      # Need to make a copy in case there are multiple source columns
      # mapping to the same term (e.g. with areas)
      rows << Hash[ row.headers.each.map { |h| [ remap(h), row[h].nil? ? nil : row[h].tidy ] } ]
    end
    rows
  end
end

class Source::JSON < Source
  def fields 
    []
  end
end



class Source::Membership < Source::CSV
  def is_memberships?
    true
  end

  def id_map_file
    filename.sub(/.csv$/, '-ids.csv')
  end

  def id_map
    return {} unless File.exists?(id_map_file)
    Hash[::CSV.table(id_map_file, converters: nil).map { |r| [r[:id], r[:uuid]] }]
  end

  def write_id_map_file!(data)
    ::CSV.open(id_map_file, 'w') do |csv|
      csv << [:id, :uuid]
      data.each { |id, uuid| csv << [id, uuid] }
    end
  end

  # Currently we just recognise a hash of k:v pairs to accept if matching
  # TODO: add 'reject' and more complex expressions
  def filtered_table
    return as_table unless i(:filter)
    filter = ->(row) { i(:filter)[:accept].all? { |k, v| row[k] == v } }
    @_filtered ||= as_table.select { |row| filter.call(row) }
  end
end

class Source::Person < Source::CSV
  def is_bios?
    true
  end
end

class Source::Wikidata < Source::CSV
  def is_bios?
    true
  end

  def fields
    # add :identifier__wikidata to the existing fields

    # but `super` fails in this context with:
    #    TypeError: self has wrong type to call super in this context: Source::Wikidata (expected Binding)
    #   
    binding.pry
  end
end

class Source::OCD < Source::CSV
  def fields 
    %i(area area_id)
  end
end

class Source::Gender < Source::CSV
  def fields 
    %i(gender)
  end
end

class Source::Term < Source::CSV
  def fields 
    []
  end
end

class Source::Group < Source::JSON
end

class Source::Area < Source::JSON
end

class Source::Positions < Source::JSON
end

