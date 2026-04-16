# @summary Attributes accepted by the victorialogs::instance defined type
type Victorialogs::InstanceType = Struct[{
  Optional[ensure]         => Enum['absent', 'present'],
  Optional[service_active] => Boolean,
  Optional[service_enable] => Variant[Boolean, Enum['mask']],
  Optional[options]        => Hash[String[1], Victorialogs::Options],
  Optional[limit_nofile]   => Integer,
}]
