Sequel.migration do
  up do
    create_table :pows do
      String :key, null: false, unique: true, primary_key: true
      String :wanted
      FalseClass :solved, null: false, default: false
    end
  end
end
