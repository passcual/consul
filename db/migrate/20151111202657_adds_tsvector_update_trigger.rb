class AddsTsvectorUpdateTrigger < ActiveRecord::Migration

  def up
    #Adds a tsvector column for the body
    add_column :proposals, :tsv, :tsvector

    # Adds an index for this new column
    execute <<-SQL
      CREATE INDEX index_proposals_on_tsv ON proposals USING gin(tsv);
    SQL

    # Updates existing rows so this new column gets calculated
    execute <<-SQL
      UPDATE proposals SET tsv = (to_tsvector('spanish', coalesce(description, '')));
    SQL

    # Sets up a trigger to update this new column on inserts and updates
    execute <<-SQL
      CREATE TRIGGER tsvectorupdate BEFORE INSERT OR UPDATE
      ON proposals FOR EACH ROW EXECUTE PROCEDURE
      tsvector_update_trigger(tsv, 'pg_catalog.spanish', description);
    SQL

    now = Time.current.to_s(:db)
    update("UPDATE proposals SET updated_at = '#{now}'")
  end

  def down
    execute <<-SQL
      DROP INDEX index_proposals_on_tsv;
    SQL

    execute <<-SQL
      DROP TRIGGER tsvectorupdate
      ON proposals
    SQL

    remove_column :proposals, :tsv
  end

end
