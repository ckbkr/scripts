# Written by Cookie Baker
#coding: utf-8

# Use --help to see a list of commands
# Excuse the messy copy paste way of coding here, I wasn't paying much attention while doing this

require 'sqlite3'
require 'json'
require 'mysql' 
require 'optparse'
require 'unicode'

class MapEntries

  def initialize
    @unpackCommand = "bzip2 -dkf " 
    @packCommand = "bzip2 -zkf9 "
    
    @serverPath = "/home/csgo/csgo_ds/csgo"
    @mapPath = "maps"
    @materialsPath = "materials"
    @modelsPath = "models"
    @trailsPath = "materials/sprites"
    @ckSurfDB = "addons/sourcemod/data/sqlite/cksurf-sqlite.sq3"
    @umcConfig = [ 0, 5, 2, 2, 1, 1, 1 ]

    @storeDBHost = "localhost"
    @storeDBUser = "root"
    @storeDBPass = "lukas"
    @storeDBName = "store"
    
    @hddArms = Hash.new
    @hddSkins = Hash.new 
    @databaseSkins = Hash.new
    
    @hddTrails = Hash.new
    @databaseTrails = Hash.new
  end

  def unpack(path,onlyMissing=false)
    @mapDir = @serverPath+"/"+@mapPath
    files = Dir.new(@mapDir)
    entries = files.entries
    counter = 0
    entries.each do |entry|
      counter = counter +1 
      if entry.end_with? ".bz2"
        if onlyMissing == true
        #TODO: this doesnt report exisiting files for vmt or mdl.. peek into bz2 instead?
          if File.exist? (@mapDir+"/"+entry[0,(entry.rindex ".bsp")])
            p "Exists: " + entry[0,(entry.rindex ".bsp")]
            next
          end
        end
        p "Progress: " + counter.to_s + "/" + entries.size.to_s
        join = "cd " + @mapDir + " && " + @unpackCommand + entry
        ret = `#{join}`
        p join
      end
    end  
    p "Done unpacking"
  end    

  def pack(path,onlyMissing=false,extension="")
    @mapDir = @serverPath+"/"+@mapPath
    files = Dir.new(@mapDir)
    entries = files.entries
    counter = 0
    entries .each do |entry|
      counter = counter +1 
      if ( entry.end_with? extension || ( extension == "" && !(entry.end_with? ".bz2") ) )
        if onlyMissing == true
          if File.exist? (@mapDir+"/"+entry +".bz2")
            p "Exists: " + entry+".bz2"
            next
          end
        end
        p "Progress: " + counter.to_s + "/" + entries.size.to_s
        join = "cd " + @mapDir + " && " + @packCommand + entry
        ret = `#{join}`
        p join
    end
  end
    p "Done packing"
  end

  def createMapList(writeToFile=true)
    @mapDir = @serverPath+"/"+@mapPath
    mapList = File.open("maplist.txt", 'w')
    arrMapList = Array.new
    files = Dir.new(@mapDir)
    files.entries.each do |entry|
      if entry.end_with? ".bsp"
        map = entry[0,(entry.rindex ".bsp")]
        #p map
        if writeToFile == true
          mapList << map + "\n"
        end
        arrMapList.push map
      end
    end
    arrMapList
  end

  def createUMCList(mapList)
    db = SQLite3::Database.open @serverPath + "/" + @ckSurfDB 
    db.results_as_hash = true
    stm = db.prepare "SELECT mapname, count(CASE WHEN zonetype = 3 THEN 1 ELSE NULL END)+1 AS stages, \
                      (SELECT tier FROM ck_maptier b WHERE b.mapname = a.mapname) AS tier, count(DISTINCT zonegroup)-1 AS bonuses \
                      FROM ck_zones a \
                      GROUP BY mapname \
                      ORDER BY tier ASC; "

    rs = stm.execute
    count = 0;
    mapInfo = Hash.new
    # name, stages, tier, bonus
    while (row = rs.next) do
      count = count + 1
      mapInfo[row['mapname']] = [  row['stages'], row['tier'],  row['bonuses'] ]
    end

    p "Maps in db: " + count.to_s
    p "Maps in list: " + mapList.length.to_s    

    mappedResult = { 0 => Array.new, 1 => Array.new, 2 => Array.new, 3 => Array.new, 4 => Array.new, 5 => Array.new, 6 => Array.new }

    count = 0

    mapcycleFile = File.open("mapcycle.txt","w")
    mapList.each do |map| 
      mapped = mapInfo[map]
      if mapped != nil
        count = count + 1
        mapTier = 0
        if mapped[1] == nil 
          mapTier = 0
        else
          mapTier = mapped[1]
        end
        mappedResult[mapTier].push([map, mapped[0], mapped[2]])
        mapcycleFile << map + "\n"
      end
    end
    p "Mapped: " + count.to_s
    
    umcFile = File.open("umc_mapcycle.txt","w")
    umcFile << "\"umc_mapcycle\"\n"
    umcFile << "{\n"
    
    for i in 0..6
      if !(mappedResult[i].empty?) 
        if i == 0 
          umcFile << "    \"No Tier\"\n"
        else
          umcFile << "    \"Tier "+i.to_s+"\"\n"
        end
        umcFile << "    {\n"
        umcFile << "        \"maps_invote\" \"" + @umcConfig[i].to_s + "\"\n"
        mappedResult[i].each do |res|
          umcFile << "        \""+res[0]+"\"        { \"display\"        \""+res[0]+" (T" + i.to_s
          if res[1] > 1 
            umcFile << " " + res[1].to_s + "S"
          else
            umcFile << " L"
          end
          if res[2] > 0
            umcFile << " " + res[2].to_s + "B"
          end 
            umcFile << ")\" }\n"
        end
        umcFile << "    }\n"
      end
    end
    umcFile << "}\n"
  end

  def scanSkins(parent,child,removePrefix="",ending=".mdl")
    if child.empty? == true 
      path = parent
    else
      path = parent+"/"+child
    end
    curr = Dir.new(path)
    curr.entries().each do |entry|
      if entry.end_with? ending 
        name = entry[0,entry.rindex(ending)]
        if name.end_with? "arms"
          while (@hddSkins[name] != nil) do
            name = name + "_"
          end
          path.slice! removePrefix
          @hddArms[name] = { "path" => path, "file" => entry }
          next 
        end
        name.gsub! "_", " "
        while (@hddSkins[name] != nil) do
          name = name + "_"
        end
        path.slice! removePrefix
        #name = Unicode::capitalize(name)
        name.gsub!(/\S+/, &:capitalize)
        @hddSkins[name] = { "filepath" => path, "file" => entry }
      end
      
      begin 
        if File.directory?(path+"/"+entry) && entry != ".." && entry != "." 
          scanSkins path,entry,removePrefix,ending
        end
      rescue
      end
    end
  end

  def scanTrails(parent,child,removePrefix="",ending=".vmt")
    if child.empty? == true 
      path = parent
    else
      path = parent+"/"+child
    end
    curr = Dir.new(path)
    curr.entries().each do |entry|
      if entry.end_with? ending 
        name = entry[0,entry.rindex(ending)]
        name.gsub! "_", " "
        while (@hddTrails[name] != nil) do
          name = name + "_"
        end
        path.slice! removePrefix
        #name = Unicode::capitalize(name)
        name.gsub!(/\S+/, &:capitalize)
        @hddTrails[name] = { "filepath" => path, "file" => entry }
      end
      
      begin 
        if File.directory?(path+"/"+entry) && entry != ".." && entry != "." 
          scanTrails path,entry,removePrefix,ending
        end
      rescue
      end
    end
  end

  def joinArms
    @hddArms.each do |k,values|
      mainFile = values["file"]
      mainFile = mainFile[0,mainFile.rindex("_arms")]
      #p mainFile
      if ( ret = @hddSkins.find { |k,v| v["file"] == mainFile+".mdl" } ) != nil
        #p "Found arms for this model: " + ret.to_s
        ret[1]["arms"] = values["file"]
        ret[1]["armspath"] = values["path"]
    values["matched"] = true
      end
    end
    @hddArms.delete_if { |k,v| v["matched"] != nil }
    p "Remaining arms: "
    p @hddArms
  end

  def listSkins
    scanSkins ( @serverPath + "/" + @modelsPath), "", @serverPath + "/"
    scanSkins ( @serverPath + "/" + @materialsPath), "", @serverPath + "/"
    joinArms
  end
  
  def listTrails
    scanTrails ( @serverPath + "/" + @trailsPath), "", @serverPath + "/"
  end
  
  def openDatabase
    db = Mysql.new( @storeDBHost, @storeDBUser, @storeDBPass, @storeDBName )   
  end
  
  def loadSkins(db)
    # as hash is actually default
    res = db.query("select id,name,attrs from store_items where type = 'skin'")
    databaseSkins = Hash.new
    res.each do |entry|
      json = JSON.parse(entry[2])
      @databaseSkins[entry[1]] = { "id" => entry[0], "model" => json["model"], "arms" => json["arms"] }
    end
  end
  
  def loadTrails(db)
    # as hash is actually default
    res = db.query("select id,name,attrs from store_items where type = 'trails'")
    databaseSkins = Hash.new
    res.each do |entry|
      json = JSON.parse(entry[2])
      @databaseTrails[entry[1]] = { "id" => entry[0], "material" => json["material"] }
    end
  end

  def mergeHDDDatabaseTrails(db)
    @databaseTrails.each do |k,values|
      file = values["material"]
      if (ret = @hddTrails.find { | k,v | (v["filepath"]+"/"+v["file"]) == file } ) != nil 
        #p "Found HDD representation of database: " + file
        ret[1]["present"] = true
        values["present"] = true
      end
    end

    @hddTrails.delete_if { |k,v| v["present"] != nil }
    p "Skins not in database:" 
    p @hddTrails
    p "Skins missing from hdd:"
    @deleteTrails = @databaseTrails.select { |k,v| v["present"] == nil }
    p @deleteTrails

    # Resolve name conflicts right away
    @hddTrails.each do |k,values|
      values["name"] = k
      loop do
        if ( (@databaseTrails.select { |k,v| v == values["name"] }).empty? )
          break
        end
        values["name"] = values["name"] + "_"
      end
    end
    updateDBTrails( db,  @hddTrails, @deleteTrails )
  end

  def mergeHDDDatabaseSkins(db)
    @databaseSkins.each do |k,values|
      file = values["model"]
      if (ret = @hddSkins.find { | k,v | (v["filepath"]+"/"+v["file"]) == file } ) != nil 
        #p "Found HDD representation of database: " + file
        ret[1]["present"] = true
        values["present"] = true
        if ret[1]["arms"] != nil && ret[1]["armspath"] != nil 
          if values["arms"] != nil && values["arms"] != ret[1]["armspath"] +"/"+ ret[1]["arms"] 
            #binding.pry
            values["arms"] = ret[1]["arms"]
            ret[1]["modified"] = true
          end
          #p "Arms added"
        end
      end
    end
    p "Skins needed to be updated in database"
    @updateEntries = @hddSkins.select { |k,v| v["modified"] != nil }
    p @updateEntries
    @hddSkins.delete_if { |k,v| v["present"] != nil }
    p "Skins not in database:" 
    p @hddSkins
    p "Skins missing from hdd:"
    @deleteSkins = @databaseSkins.select { |k,v| v["present"] == nil }
    p @deleteSkins
    p "Setting delete value to empty"
    @deleteSkins = {}
    # Resolve name conflicts right away
    @hddSkins.each do |k,values|
      values["name"] = k
      loop do
        if ( (@databaseSkins.select { |k,v| v == values["name"] }).empty? )
          break
        end
        values["name"] = values["name"] + "_"
      end
    end
    updateDBSkins( db, @updateEntries, @hddSkins, @deleteSkins )
  end
  
  
  
  def mergeTrails(db)
    loadTrails(db)
    listTrails
    mergeHDDDatabaseTrails(db)
  end

  def mergeSkins(db)
    loadSkins(db)
    listSkins
    mergeHDDDatabaseSkins(db)
  end
  
  def getCategoryFromDB(db,category)
    sqlFindCategory = "select id from store_categories where require_plugin='"+category+"'"
    res = db.query(sqlFindCategory)
    category = nil
    begin 
      category = res.fetch_row[0]
    rescue
      p "Failed to retrieve '"+category+"' category from database"
      return nil
    end
    category
  end
  
  def deleteSkinsFromDB(db)
     skin_category = getCategoryFromDB(db,"skin")
     if skin_category == nil
       return 0
     end
     
     sqlDeleteAllSkins = "delete from store_items where category_id = ?" 
     stmt = db.prepare sqlDeleteAllSkins  
     stmt.execute skin_category
  end
  
  def deleteTrailsFromDB(db)
     trails_category = getCategoryFromDB(db,"trails")
     if trails_category == nil
       return 0
     end
     
     sqlDeleteAllSkins = "delete from store_items where category_id = ?" 
     stmt = db.prepare sqlDeleteAllSkins  
     stmt.execute trails_category
  end
  
  
  
  def updateDBTrails( db,  addEntries = {}, deleteEntries = {} )
    sqlInsertTrail = "insert into store_items(name,display_name,type,loadout_slot,category_id,attrs) values(?,?,?,?,?,?)"
    sqlDeleteTrail = "delete from store_items where id=?"
    
    trail_category = getCategoryFromDB(db,"trails")
    if trail_category == nil
      return 0
    end
    
    stmt = db.prepare sqlDeleteTrail 
    deleteEntries.each do |k,values|
      p "Deleting from database: " + k
      begin
        stmt.execute values["id"]
      rescue
      end
    end

    stmt = db.prepare sqlInsertTrail 
    addEntries.each do |k,values|
      
      jsonHash = { "material" => values["filepath"] + "/" + values["file"],  "teams" => [ 2, 3] }
      begin
        stmt.execute "trail_"+values["name"], values["name"], "trails", "trails", trail_category, JSON.pretty_generate(jsonHash)
      rescue
      end
    end
  end

  def updateDBSkins( db, updateEntries = {}, addEntries = {}, deleteEntries = {} )
    sqlUpdateSkin = "update store_items set name=?, attrs=? where id=?"
    sqlInsertSkin = "insert into store_items(name,display_name,type,loadout_slot,category_id,attrs) values(?,?,?,?,?,?)"
    sqlDeleteSkin = "delete from store_items where id=?"

    skin_category = getCategoryFromDB(db,"skin")
    if skin_category == nil
      return 0
    end

    stmt = db.prepare sqlDeleteSkin 
    deleteEntries.each do |k,values|
      p "Deleting from database: " + k
      begin
        stmt.execute values["id"]
      rescue
      end
    end

    stmt = db.prepare sqlUpdateSkin 
    updateEntries.each do |k,values|
      p "Updating in database: " + k
      arms = String.new
      if values["armspath"] != nil && values["arms"] != nil 
        arms = values["armspath"] + "/" + values["arms"]
      end
      jsonHash = { "model" => values["filepath"] + "/" + values["file"], "arms" => arms, "teams" => [ 2, 3]  }
      begin
        stmt.execute k, JSON.pretty_generate(jsonHash), values["id"] 
      rescue
      end
    end

    stmt = db.prepare sqlInsertSkin 
    addEntries.each do |k,values|
      arms = String.new
      if values["armspath"] != nil && values["arms"] != nil 
        arms = values["armspath"] + "/" + values["arms"]
      end
      jsonHash = { "model" => values["filepath"] + "/" + values["file"], "arms" => arms, "teams" => [ 2, 3] }
      begin
        stmt.execute "skin_"+values["name"], values["name"], "skin", "skin", skin_category, JSON.pretty_generate(jsonHash)
      rescue
      end
    end
  end

  
  def entry
    options = {}
    OptionParser.new do |opts|
      opts.banner = "Usage: " + File.basename(__FILE__) +" [options]"
    
      opts.on("", "--pack_maps", "pack map bz2 files") do |u|
        options[:packmaps] = u
      end
      
      opts.on("", "--pack_materials", "pack map bz2 files") do |u|
        options[:packmod] = u
      end
      
      opts.on("", "--pack_models", "pack map bz2 files") do |u|
        options[:packmat] = u
      end
      
      
      opts.on("", "--unp_maps", "unpack map bz2 files") do |pa|
        options[:unpmap] = pa
      end
      
      opts.on("", "--unp_materials", "unpack materials bz2 files") do |pa|
        options[:unpmap] = pa
      end
      
      opts.on("", "--unp_models", "unpack models bz2 files") do |pa|
        options[:unpmap] = pa
      end
      
      opts.on("", "--existing", "do not unpack/pack files of which the map,etc/archive file already exists") do |e|
        options[:existing] = e
      end
      
      opts.on("-l", "--list", "print a maplist.txt file according to the current maps") do |ml|
        options[:maplist] = ml
      end
      
      opts.on("-c", "--cycle", "create a umc mapcycle and print the umc cycle as well as the map cycle, uses ckSurf db to resolve tiers and stages") do |mc|
        options[:mapcycle] = mc
      end
      
      opts.on("", "--drop_skins", "delete all skins from the database") do |ds|
        options[:dropskins] = ds
      end
      
      opts.on("", "--drop_trails", "delete all trails from the database") do |ds|
        options[:droptrails] = ds
      end
      
      opts.on("", "--import_skins", "import skins to the database from the mods/materials folder") do |is|
        options[:importskins] = is
      end
      
      opts.on("", "--import_trails", "import trails to the database from the mods/materials folder") do |it|
        options[:importrails] = it
      end
    end.parse!

   
    if options[:unpmap] == true 
      if options[:existing] == true
        unpack(@serverPath+"/"+@mapPath,true)
      else
        unpack(@serverPath+"/"+@mapPath)
      end
    end
    
    if options[:packmaps] == true 
      if options[:existing] == true
        pack(@serverPath+"/"+@mapPath,true,".bsp")
      else
        pack(@serverPath+"/"+@mapPath,".bsp")
      end
    end
    
    # I regret doing this idea of packing materials and models this way
    
    
    
    maplist = nil
    if options[:maplist] == true 
      maplist = createMapList
    end
    
    mapcycle = nil
    if options[:mapcycle] == true 
      if maplist == nil
        maplist = createMapList(false)
      end
      createUMCList(maplist)
    end
    
    database = nil
    
    if options[:dropskins] == true 
      db = openDatabase
      deleteSkinsFromDB(db)
    end
    
    if options[:droptrails] == true 
      if db == nil
        db = openDatabase
      end
      deleteTrailsFromDB(db)
    end
    
    if options[:importskins] == true 
      if db == nil
        db = openDatabase
      end
      mergeSkins(db)
    end
    
    if options[:importrails] == true 
      if db == nil
        db = openDatabase
      end
      mergeTrails(db)
    end
    
    
    
  end

end

MapEntries.new.entry