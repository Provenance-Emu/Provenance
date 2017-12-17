class MD_Multitap final : public MD_Input_Device
{
        public:
        MD_Multitap();
        virtual ~MD_Multitap() override;
	virtual void UpdateBus(const int32 master_timestamp, uint8 &bus, const uint8 genesis_asserted) override;
	virtual void StateAction(StateMem *sm, const unsigned load, const bool data_only, const char *section_prefix) override;
	virtual void Power(void) override;
        virtual void BeginTimePeriod(const int32 timestamp_base) override;
        virtual void EndTimePeriod(const int32 master_timestamp) override;

	void SetSubPort(unsigned n, MD_Input_Device* d);

	private:
	MD_Input_Device* SubPort[4] = { nullptr, nullptr, nullptr, nullptr };

	unsigned phase;
	bool prev_th, prev_tr;

	uint8 bb[4][5];
	uint64 data_out;
	unsigned data_out_offs;
	uint8 nyb;
};

