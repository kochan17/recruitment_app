class CreateResumes < ActiveRecord::Migration[7.1]
  def change
    create_table :resumes do |t|

      t.timestamps
    end
  end
end
