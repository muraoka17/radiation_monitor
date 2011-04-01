class CreateRadiations < ActiveRecord::Migration
	def self.up
		create_table(:radiations) do |t|
			t.string(:location, :limit => 64)
			t.string(:place, :limit => 10)
			t.float(:gamma_ray)
			t.float(:neutron_radiation)
			t.string(:wind_direction)
			t.float(:wind_speed)
			t.datetime(:measured_at)
			t.timestamps
		end
	end

	def self.down
		drop_table(:radiations)
	end
end
