require 'spec_helper'
require 'support/helpers'

shared_examples_for 'temporal table' do
  it { should_not have_public_backing }

  it { should have_temporal_backing }
  it { should have_history_backing }
  it { should have_history_extra_columns }
  it { should have_public_interface }

  it { should have_columns(columns) }
  it { should have_temporal_columns(columns) }
  it { should have_history_columns(columns) }
end

shared_examples_for 'plain table' do
  it { should have_public_backing }

  it { should_not have_temporal_backing }
  it { should_not have_history_backing }
  it { should_not have_public_interface }

  it { should have_columns(columns) }
end

describe ChronoModel::Adapter do
  include ChronoTest::Helpers::Adapter

  it { adapter.should be_a_kind_of(ChronoModel::Adapter) }

  let(:table) { 'test_table' }
  subject { table }

  columns do
    native = [
      ['test', 'character varying(255)'],
      ['foo',  'integer'],
      ['bar',  'double precision'],
      ['baz',  'text']
    ]

    def native.to_proc
      proc {|t|
        t.string  :test
        t.integer :foo
        t.float   :bar
        t.text    :baz
      }
    end

    native
  end

  describe '.create_table' do
    with_temporal_table do
      it_should_behave_like 'temporal table'
    end

    with_plain_table do
      it_should_behave_like 'plain table'
    end
  end

  describe '.rename_table' do
    let(:table)   { 'test_table' }
    let(:renamed) { 'foo_table'  }
    subject { renamed }

    context ':temporal => true' do
      before :all do
        adapter.create_table table, :temporal => true, &columns

        adapter.rename_table table, renamed
      end
      after(:all) { adapter.drop_table(renamed) }

      it_should_behave_like 'temporal table'
    end

    context ':temporal => false' do
      before :all do
        adapter.create_table table, :temporal => false, &columns

        adapter.rename_table table, renamed
      end
      after(:all) { adapter.drop_table(renamed) }

      it_should_behave_like 'plain table'
    end
  end

  describe '.change_table' do
    with_temporal_table do
      before :all do
        adapter.change_table table, :temporal => false
      end

      it_should_behave_like 'plain table'
    end

    with_plain_table do
      before :all do
        adapter.change_table table, :temporal => true
      end

      it_should_behave_like 'temporal table'
    end
  end

  describe '.drop_table' do
    before :all do
      adapter.create_table table, :temporal => true, &columns

      adapter.drop_table table
    end

    it { should_not have_public_backing }
    it { should_not have_temporal_backing }
    it { should_not have_history_backing }
    it { should_not have_public_interface }
  end

  describe '.add_index' do
    with_temporal_table do
      before :all do
        adapter.add_index table, [:foo, :bar], :name => 'foobar_index'
        adapter.add_index table, [:test],      :name => 'test_index'
      end

      it { should have_temporal_index 'foobar_index', %w( foo bar ) }
      it { should have_history_index  'foobar_index', %w( foo bar ) }
      it { should have_temporal_index 'test_index',   %w( test ) }
      it { should have_history_index  'test_index',   %w( test ) }

      it { should_not have_index 'foobar_index', %w( foo bar ) }
      it { should_not have_index 'test_index',   %w( test ) }
    end

    with_plain_table do
      before :all do
        adapter.add_index table, [:foo, :bar], :name => 'foobar_index'
        adapter.add_index table, [:test],      :name => 'test_index'
      end

      it { should_not have_temporal_index 'foobar_index', %w( foo bar ) }
      it { should_not have_history_index  'foobar_index', %w( foo bar ) }
      it { should_not have_temporal_index 'test_index',   %w( test ) }
      it { should_not have_history_index  'test_index',   %w( test ) }

      it { should have_index 'foobar_index', %w( foo bar ) }
      it { should have_index 'test_index',   %w( test ) }
    end
  end

  describe '.remove_index' do
    with_temporal_table do
      before :all do
        adapter.add_index table, [:foo, :bar], :name => 'foobar_index'
        adapter.add_index table, [:test],      :name => 'test_index'

        adapter.remove_index table, :name => 'test_index'
      end

      it { should_not have_temporal_index 'test_index', %w( test ) }
      it { should_not have_history_index  'test_index', %w( test ) }
      it { should_not have_index          'test_index', %w( test ) }
    end

    with_plain_table do
      before :all do
        adapter.add_index table, [:foo, :bar], :name => 'foobar_index'
        adapter.add_index table, [:test],      :name => 'test_index'

        adapter.remove_index table, :name => 'test_index'
      end

      it { should_not have_temporal_index 'test_index', %w( test ) }
      it { should_not have_history_index  'test_index', %w( test ) }
      it { should_not have_index          'test_index', %w( test ) }
    end
  end

  describe '.add_column' do
    let(:extra_columns) { [['foobarbaz', 'integer']] }

    with_temporal_table do
      before :all do
        adapter.add_column table, :foobarbaz, :integer
      end

      it { should have_columns(extra_columns) }
      it { should have_temporal_columns(extra_columns) }
      it { should have_history_columns(extra_columns) }
    end

    with_plain_table do
      before :all do
        adapter.add_column table, :foobarbaz, :integer
      end

      it { should have_columns(extra_columns) }
    end
  end

  describe '.remove_column' do
    let(:resulting_columns) { columns.reject {|c,_| c == 'foo'} }

    with_temporal_table do
      before :all do
        adapter.remove_column table, :foo
      end

      it { should have_columns(resulting_columns) }
      it { should have_temporal_columns(resulting_columns) }
      it { should have_history_columns(resulting_columns) }

      it { should_not have_columns([['foo', 'integer']]) }
      it { should_not have_temporal_columns([['foo', 'integer']]) }
      it { should_not have_history_columns([['foo', 'integer']]) }
    end

    with_plain_table do
      before :all do
        adapter.remove_column table, :foo
      end

      it { should have_columns(resulting_columns) }
      it { should_not have_columns([['foo', 'integer']]) }
    end
  end

  describe '.rename_column' do
    with_temporal_table do
      before :all do
        adapter.rename_column table, :foo, :taratapiatapioca
      end

      it { should_not have_columns([['foo', 'integer']]) }
      it { should_not have_temporal_columns([['foo', 'integer']]) }
      it { should_not have_history_columns([['foo', 'integer']]) }

      it { should have_columns([['taratapiatapioca', 'integer']]) }
      it { should have_temporal_columns([['taratapiatapioca', 'integer']]) }
      it { should have_history_columns([['taratapiatapioca', 'integer']]) }
    end

    with_plain_table do
      before :all do
        adapter.rename_column table, :foo, :taratapiatapioca
      end

      it { should_not have_columns([['foo', 'integer']]) }
      it { should have_columns([['taratapiatapioca', 'integer']]) }
    end
  end

  describe '.change_column' do
    with_temporal_table do
      before :all do
        adapter.change_column table, :foo, :float
      end

      it { should_not have_columns([['foo', 'integer']]) }
      it { should_not have_temporal_columns([['foo', 'integer']]) }
      it { should_not have_history_columns([['foo', 'integer']]) }

      it { should have_columns([['foo', 'double precision']]) }
      it { should have_temporal_columns([['foo', 'double precision']]) }
      it { should have_history_columns([['foo', 'double precision']]) }
    end

    with_plain_table do
      before(:all) do
        adapter.change_column table, :foo, :float
      end

      it { should_not have_columns([['foo', 'integer']]) }
      it { should have_columns([['foo', 'double precision']]) }
    end
  end

  describe '.remove_column' do
    with_temporal_table do
      before :all do
        adapter.remove_column table, :foo
      end

      it { should_not have_columns([['foo', 'integer']]) }
      it { should_not have_temporal_columns([['foo', 'integer']]) }
      it { should_not have_history_columns([['foo', 'integer']]) }
    end

    with_plain_table do
      before :all do
        adapter.remove_column table, :foo
      end

      it { should_not have_columns([['foo', 'integer']]) }
    end
  end

  describe '.column_definitions' do
    subject { adapter.column_definitions(table).map {|d| d.take(2)} }

    assert = proc do
      it { (subject & columns).should == columns }
      it { should include(['id', 'integer']) }
    end

    with_temporal_table &assert
    with_plain_table    &assert
  end

  describe '.primary_key' do
    subject { adapter.primary_key(table) }

    assert = proc do
      it { should == 'id' }
    end

    with_temporal_table &assert
    with_plain_table    &assert
  end

  describe '.indexes' do
    subject { adapter.indexes(table) }

    assert = proc do
      before(:all) do
        adapter.add_index table, :foo,         :name => 'foo_index'
        adapter.add_index table, [:bar, :baz], :name => 'bar_index'
      end

      it { subject.map(&:name).should =~ %w( foo_index bar_index ) }
      it { subject.map(&:columns).should =~ [['foo'], ['bar', 'baz']] }
    end

    with_temporal_table &assert
    with_plain_table    &assert
  end

  describe '.on_schema' do
    before(:all) do
      5.times {|i| adapter.execute "CREATE SCHEMA test_#{i}"}
    end

    context 'with nesting' do

      it 'saves the schema at each recursion' do
        should be_in_schema(:default)

        adapter.on_schema('test_1') { should be_in_schema('test_1')
          adapter.on_schema('test_2') { should be_in_schema('test_2')
            adapter.on_schema('test_3') { should be_in_schema('test_3')
            }
            should be_in_schema('test_2')
          }
          should be_in_schema('test_1')
        }

        should be_in_schema(:default)
      end

    end

    context 'without nesting' do
      it 'ignores recursive calls' do
        should be_in_schema(:default)

        adapter.on_schema('test_1', false) { should be_in_schema('test_1')
          adapter.on_schema('test_2', false) { should be_in_schema('test_1')
            adapter.on_schema('test_3', false) { should be_in_schema('test_1')
        } } }

        should be_in_schema(:default)
      end
    end
  end

end
