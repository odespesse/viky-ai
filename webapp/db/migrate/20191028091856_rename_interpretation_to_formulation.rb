class RenameInterpretationToFormulation < ActiveRecord::Migration[6.0]
  def change
    rename_table :interpretations, :formulations
    rename_column :interpretation_aliases, :interpretation_id, :formulation_id
  end
end
