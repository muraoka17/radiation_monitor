require "faster_csv"
require "mechanize"

agent = Mechanize.new
page = agent.get("http://www.mext.go.jp/a_menu/saigaijohou/syousai/1303723.htm")
page.links_with(:href => /.+\.pdf$/, :text => /^環境放射能水準調査結果\(都道府県別\)/).each do |link|
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
	dates = []
	measured_ats = []
	col_size = nil
	faster_csv.each_with_index do |row, i|
		if row[0] =~ /^(\d+)月(\d+)日$/
			dates = row.map {|r| r.sub(/(\d+)月(\d+)日/, '2011-\1-\2')}
			next
		end

		if row[0] =~ /^\d+\-\d+$/
			tmp_dates = dates.dup
			date = tmp_dates.shift
			measured_ats = row[0..-2].map{|r| 
				hour = r.sub(/\-\d+/, '')
				date = tmp_dates.shift if hour == "0" && tmp_dates.present?
				DateTime.strptime("#{date} #{hour}:00", "%Y-%m-%d %H:%M")
			}
			next
		end

		if row[0].to_i > 0 && row[0].to_i < 48 && row.size == measured_ats.size + 3
			location = case row[0].to_i
								 when 1..7
									 "北海道・東北"
								 when 8..14
									 "関東"
								 when 15..20
									 "北陸・甲信越"
								 when 21..24
									 "東海"
								 when 25..30
									 "近畿"
								 when 31..35
									 "中国"
								 when 36..39
									 "四国"
								 when 40..47
									 "九州"
								 end
			row[2..-2].each_with_index do |value, i|
				records << {:location => location, :place => row[1], :measured_at => measured_ats[i], :gamma_ray => value}
			end
		end
	end

	Radiation.seed_many(:location, :place, :measured_at, records)
end
