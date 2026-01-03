require "rails_helper"

RSpec.describe Plan, type: :model do
  let(:monthly) { plans(:personal) }
  let(:annual) { plans(:personal_annual) }

  describe "#find_interval_plan" do
    it "finds the alternate interval plan" do
      expect(monthly.find_interval_plan).to eq(annual)
      expect(annual.find_interval_plan).to eq(monthly)
    end
  end

  describe "interval methods" do
    it "#monthly? returns true for monthly plans" do
      expect(monthly).to be_monthly
      expect(annual).not_to be_monthly
    end

    it "#annual? returns true for annual plans" do
      expect(annual).to be_annual
      expect(monthly).not_to be_annual
    end

    it "#yearly? returns true for annual plans" do
      expect(annual).to be_yearly
      expect(monthly).not_to be_yearly
    end
  end

  describe "version methods" do
    it "#monthly_version returns the monthly plan" do
      expect(annual.monthly_version).to eq(monthly)
    end

    it "#yearly_version returns the annual plan" do
      expect(monthly.yearly_version).to eq(annual)
    end

    it "#annual_version returns the annual plan" do
      expect(monthly.annual_version).to eq(annual)
    end
  end

  describe "scopes" do
    it "default scope only has visible plans" do
      expect(Plan.visible).not_to include(plans(:hidden))
      expect(Plan.visible.count).to eq(Plan.count - Plan.hidden.count)
    end

    it "visible doesn't include hidden plans" do
      expect(Plan.visible).to include(plans(:personal))
      expect(Plan.visible).not_to include(plans(:hidden))
    end

    it "hidden doesn't include visible plans" do
      expect(Plan.hidden).to include(plans(:hidden))
      expect(Plan.hidden).not_to include(plans(:personal))
    end
  end

  describe "stripe_tax" do
    it "converts stripe_tax to boolean" do
      plan = Plan.first
      plan.stripe_tax = "1"
      expect(plan.stripe_tax).to be true

      plan.stripe_tax = "0"
      expect(plan.stripe_tax).to be false
    end
  end

  describe "charge_per_unit validation" do
    it "requires unit label if charge_by_unit enabled" do
      plan = Plan.new(charge_per_unit: true, unit_label: "")
      expect(plan).not_to be_valid
      expect(plan.errors[:unit_label]).to be_any
    end
  end
end
