require "faster_csv"
require "mechanize"

agent = Mechanize.new
page = agent.get("http://www.tepco.co.jp/nu/monitoring/index-j.html")
page.links_with(:href => /.+\.pdf$/).each do |link|
	pdf_file = Rails.root + "/public/data/" + File.basename(link.href)
	unless File.exist?(pdf_file)
		link.click.save(pdf_file)
		print(pdf_file + " saved\n")
		sleep(1)
	end

	text_file = pdf_file.gsub(/\.pdf/, '.txt')
	unless File.exist?(text_file)
		`/usr/local/bin/pdftotext -layout #{pdf_file} #{text_file}`
		print(text_file + " saved\n")
	else
		next
	end

	print(text_file + " parsing...\n")
	faster_csv = FasterCSV.open(text_file, :col_sep => " ", :converters => [lambda {|f, info| f ? NKF.nkf("-w -WZ1", f) : f}])

	records = []
	date = ""
	location = ""
	type = ""
	places = []
	units = []
	faster_csv.each_with_index do |row, i|
		# support 3/11～3/29(first) & 3/11～(second) format
		if row[0] =~ /^(【別紙】)*(.+)モニタリング(カー)*(※)*による計測状況$/
			location = $2
			type = "car"
			next
		end

		## support 3/29～(first) format
		if row[0] =~ /^(【別紙】)*(.+)可搬型モニタリングポストによる計測状況$/
			location = $2
			type = "post"
			places = []
			units = []
			next
		end

		if row[1] == "仮設モニタリングポストによる定点計測状況"
			location = row[0]
			type = "post"
			places = []
			units = []
			next
		end

		case type
		when "car"
			if row[0] =~ /^計測日:(\d+)月(\d+)日$/
				date = "2011-#{$1}-#{$2}"
				next
			end

			# support 3/11～3/16 format
			if row[0] =~ /^(\d+)月(\d+)日$/
				date = "2011-#{$1}-#{$2}"
				row.shift
			end

			if row[0] =~ /^(午前|午後)(\d+)時(\d+)分$/
				record = {}

				time = ($1 == "午前" ? ' am ' : ' pm ') + $2 + ':' + $3
				record[:measured_at] = DateTime.strptime("#{date}#{time}", "%Y-%m-%d %p %H:%M")
				record[:location] = location
				record[:place] = row[1].gsub(/付近/, '')
				record[:gamma_ray] = row[2]
				if row[3] =~ /^(μSv\/h|nGy\/h)/
					row.slice!(3)
				end

				record[:neutron_radiation] = row[3]
				if row[4] =~ /^(μSv\/h|nGy\/h)/
					row.slice!(4)
				end

				record[:wind_direction] = row[4]
				record[:wind_speed] = row[5]

				records << record
			end
		when "post"
			if row.size == 3
				if places.empty?
					places = row
				else
					units = row
				end
				next
			end

			if row[0] =~ /^(\d)+\/(\d)+\/(\d)+$/
				measured_at = DateTime.strptime(row[0] + " " + row[1], "%Y/%m/%d %H:%M")
				gamma_rays = []
				units.each_with_index do |unit, i|
					 case unit
					 when /μSv\/h/
						 gamma_rays[i] = row[i + 2]
					 when /mSv\/h/
						 gamma_rays[i] = row[i + 2].to_f * 1000.0
					 when /nSv\/h/
						 gamma_rays[i] = row[i + 2].to_f / 1000.0
					 else
						 gamma_rays[i] = row[i + 2]
					 end
				end

				[[location] * 3, places, [measured_at] * 3, gamma_rays].transpose.each do |rec|
					records << {:location => rec[0], :place => rec[1], :measured_at => rec[2], :gamma_ray => rec[3]}
				end
			end
		end
	end

	Radiation.seed_many(:location, :place, :measured_at, records)
end
